import { syntaxTree } from "@codemirror/language";
import { RangeSetBuilder } from "@codemirror/state";
import { Decoration, ViewPlugin } from "@codemirror/view";

const urlDecoration = Decoration.mark({ class: "cm-wik-url" });
const markDecoration = Decoration.mark({ class: "cm-wik-mark" });
const MARK_NODE_NAMES = new Set(["HeaderMark", "LinkMark"]);

function buildDecorations(
	view: { state: any; viewport: { from: number; to: number } },
	filter: (name: string) => boolean,
	decoration: Decoration,
) {
	const builder = new RangeSetBuilder<Decoration>();

	syntaxTree(view.state).iterate({
		from: view.viewport.from,
		to: view.viewport.to,
		enter: (node) => {
			if (filter(node.type.name)) {
				builder.add(node.from, node.to, decoration);
			}
		},
	});

	return builder.finish();
}

const urlHighlightPlugin = ViewPlugin.fromClass(
	class {
		decorations: ReturnType<typeof buildDecorations>;

		constructor(view: { state: any; viewport: { from: number; to: number } }) {
			this.decorations = buildDecorations(
				view,
				(name) => name === "URL",
				urlDecoration,
			);
		}

		update(update: {
			docChanged: boolean;
			viewportChanged: boolean;
			view: { state: any; viewport: { from: number; to: number } };
		}) {
			if (update.docChanged || update.viewportChanged) {
				this.decorations = buildDecorations(
					update.view,
					(name) => name === "URL",
					urlDecoration,
				);
			}
		}
	},
	{
		decorations: (value) => value.decorations,
	},
);

const markHighlightPlugin = ViewPlugin.fromClass(
	class {
		decorations: ReturnType<typeof buildDecorations>;

		constructor(view: { state: any; viewport: { from: number; to: number } }) {
			this.decorations = buildDecorations(
				view,
				(name) => MARK_NODE_NAMES.has(name),
				markDecoration,
			);
		}

		update(update: {
			docChanged: boolean;
			viewportChanged: boolean;
			view: { state: any; viewport: { from: number; to: number } };
		}) {
			if (update.docChanged || update.viewportChanged) {
				this.decorations = buildDecorations(
					update.view,
					(name) => MARK_NODE_NAMES.has(name),
					markDecoration,
				);
			}
		}
	},
	{
		decorations: (value) => value.decorations,
	},
);

export { urlHighlightPlugin, markHighlightPlugin };
