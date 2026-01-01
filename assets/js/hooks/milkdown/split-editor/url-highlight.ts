import { syntaxTree } from "@codemirror/language";
import { RangeSetBuilder } from "@codemirror/state";
import { Decoration, ViewPlugin } from "@codemirror/view";

const urlDecoration = Decoration.mark({ class: "cm-wik-url" });

function buildUrlDecorations(view: {
	state: any;
	viewport: { from: number; to: number };
}) {
	const builder = new RangeSetBuilder<Decoration>();

	syntaxTree(view.state).iterate({
		from: view.viewport.from,
		to: view.viewport.to,
		enter: (node) => {
			if (node.type.name === "URL") {
				builder.add(node.from, node.to, urlDecoration);
			}
		},
	});

	return builder.finish();
}

const urlHighlightPlugin = ViewPlugin.fromClass(
	class {
		decorations: ReturnType<typeof buildUrlDecorations>;

		constructor(view: { state: any; viewport: { from: number; to: number } }) {
			this.decorations = buildUrlDecorations(view);
		}

		update(update: {
			docChanged: boolean;
			viewportChanged: boolean;
			view: { state: any; viewport: { from: number; to: number } };
		}) {
			if (update.docChanged || update.viewportChanged) {
				this.decorations = buildUrlDecorations(update.view);
			}
		}
	},
	{
		decorations: (value) => value.decorations,
	},
);

export { urlHighlightPlugin };
