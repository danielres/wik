import { Plugin } from "@milkdown/kit/prose/state";
import type { Schema } from "@milkdown/kit/prose/model";
import type { EditorState, Transaction } from "@milkdown/kit/prose/state";
import type { EditorView } from "prosemirror-view";

type Options = {
	rootEl: HTMLElement;
};

function normalizeTitle(title: string | null | undefined) {
	return (title || "").trim();
}

function buildH1(schema: Schema, title: string) {
	const heading = schema.nodes.heading;
	if (!heading) return null;
	const text = normalizeTitle(title);
	if (text === "") return null;
	return heading.create({ level: 1 }, schema.text(text));
}

function needsFix(state: EditorState) {
	const first = state.doc.firstChild;
	if (!first) return true;
	if (first.type.name !== "heading") return true;
	if (first.attrs?.level !== 1) return true;
	if (normalizeTitle(first.textContent) === "") return true;
	return false;
}

function selectionWithinFirstNode(state: EditorState) {
	const first = state.doc.firstChild;
	if (!first) return false;

	const { $from, $to } = state.selection;
	if ($from.depth < 1 || $to.depth < 1) return false;

	return $from.node(1) === first && $to.node(1) === first;
}

function makeFixTransaction(
	state: EditorState,
	fallbackTitle: string,
): Transaction | null {
	if (!needsFix(state)) return null;

	const h1 =
		buildH1(state.schema, fallbackTitle) ?? buildH1(state.schema, "Untitled");
	if (!h1) return null;

	const first = state.doc.firstChild;
	const tr = state.tr;

	if (!first) {
		return tr.insert(0, h1);
	}

	if (first.type.name === "heading" && first.attrs?.level === 1) {
		// Replace empty H1 with fallback title.
		if (normalizeTitle(first.textContent) === "") {
			// Allow temporarily clearing the H1 while actively editing it; re-fill once the
			// selection moves elsewhere.
			if (selectionWithinFirstNode(state)) return null;
			return tr.replaceWith(0, first.nodeSize, h1);
		}
		return null;
	}

	// Insert H1 at the top if first node isn't an H1.
	return tr.insert(0, h1);
}

export function ensureTitleHeadingPlugin(options: Options) {
	let view: EditorView | null = null;
	const getFallbackTitle = () =>
		normalizeTitle(options.rootEl.dataset.pageTitle);

	const maybeFixNow = (state: EditorState) => {
		if (!view?.editable) return null;
		return makeFixTransaction(state, getFallbackTitle());
	};

	return new Plugin({
		view(nextView) {
			view = nextView;
			const tr = maybeFixNow(nextView.state);
			if (tr) nextView.dispatch(tr);
			return {
				update(nextView2) {
					view = nextView2;
				},
				destroy() {
					view = null;
				},
			};
		},
		appendTransaction(trs, _oldState, newState) {
			if (!trs.some((tr) => tr.docChanged || tr.selectionSet)) return null;
			const tr = maybeFixNow(newState);
			return tr;
		},
	});
}
