import { Plugin } from "@milkdown/kit/prose/state";
import type { EditorView } from "prosemirror-view";

type PageInfo = { id: string; slug: string; title: string };

type Options = {
	resolveRef: (title: string) => Promise<PageInfo | null>;
};

const WIKIID_PREFIX = "wikid:";
const WIKIREF_PREFIX = "wikiref:";

function isResolvedPosInHeading($pos: any) {
	if (!$pos) return false;
	for (let depth = $pos.depth; depth > 0; depth--) {
		if ($pos.node(depth)?.type?.name === "heading") return true;
	}
	return false;
}

function replaceLinkMarksWithWikilink(
	view: EditorView,
	match: (href: string, text: string) => { id: string; label: string } | null,
) {
	const { state } = view;
	const { schema } = state;
	const linkMark = schema.marks.link;
	const wikilinkType = schema.nodes.wikilink;

	if (!linkMark || !wikilinkType) return;

	const tr = state.tr;
	let changed = false;

	state.doc.descendants((node: any, pos: number) => {
		if (!node?.isText) return;
		const link = (node.marks || []).find((m: any) => m.type === linkMark);
		const href = link?.attrs?.href;
		if (typeof href !== "string") return;
		if (isResolvedPosInHeading(state.doc.resolve(pos))) return;

		const text = typeof node.text === "string" ? node.text : "";
		const result = match(href, text);
		if (!result?.id) return;

		const from = tr.mapping.map(pos);
		const to = tr.mapping.map(pos + node.nodeSize);
		const wikilink = wikilinkType.create({
			id: result.id,
			label: result.label,
		});
		if (!wikilink) return;

		tr.replaceWith(from, to, wikilink);
		changed = true;
	});

	if (changed) view.dispatch(tr);
}

export function wikilinkPlugin(options: Options) {
	let view: EditorView | null = null;
	const resolving = new Map<string, Promise<PageInfo | null>>();

	const resolveTitle = (title: string) => {
		if (resolving.has(title)) return resolving.get(title)!;
		const promise = options.resolveRef(title).finally(() => {
			resolving.delete(title);
		});
		resolving.set(title, promise);
		return promise;
	};

	const maybeResolveRefs = (view2: EditorView) => {
		if (!view2.editable) return;

		replaceLinkMarksWithWikilink(view2, (href, text) => {
			if (!href.startsWith(WIKIID_PREFIX)) return null;
			const id = href.slice(WIKIID_PREFIX.length);
			if (!id) return null;
			return { id, label: text };
		});

		const linkType = (view2.state as any).schema.marks.link;
		if (!linkType) return;

		const refs = new Set<string>();

		(view2.state as any).doc.descendants((node: any, pos: number) => {
			if (!node?.isText) return;
			const link = (node.marks || []).find((m: any) => m.type === linkType);
			const href = link?.attrs?.href;
			if (typeof href !== "string") return;
			if (!href.startsWith(WIKIREF_PREFIX)) return;
			if (isResolvedPosInHeading((view2.state as any).doc.resolve(pos))) return;

			const ref = decodeURIComponent(href.slice(WIKIREF_PREFIX.length));
			if (ref.trim() === "") return;
			refs.add(ref);
		});

		for (const ref of refs) {
			resolveTitle(ref).then((page) => {
				if (!page) return;
				if (!view) return;

				replaceLinkMarksWithWikilink(view, (href, text) => {
					if (href !== `${WIKIREF_PREFIX}${encodeURIComponent(ref)}`) return null;
					return { id: String(page.id), label: text };
				});
			});
		}
	};

	return new Plugin({
		view(nextView) {
			view = nextView;
			maybeResolveRefs(nextView);

			return {
				update(nextView2) {
					view = nextView2;
					maybeResolveRefs(nextView2);
				},
				destroy() {
					view = null;
					resolving.clear();
				},
			};
		},
		// Intentionally do not special-case selection/editing behavior for wikilinks:
		// treat them like normal links (editable text, normal cursoring, normal deletion).
	});
}
