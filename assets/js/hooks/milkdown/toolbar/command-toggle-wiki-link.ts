import { editorViewCtx } from "@milkdown/core";
import type { Ctx } from "@milkdown/ctx";
import { TextSelection } from "prosemirror-state";
import { capitalize } from "../../../utils";

export const toggleWikilinkCommand = (ctx: Ctx) => {
	const view = ctx.get(editorViewCtx);
	const { state, dispatch } = view;
	const { from, to } = state.selection;

	// Get selected text
	const text = state.doc.textBetween(from, to);
	if (!text) return;

	// Create a wikilink ref; the editor will resolve it to a stable `wikid:*` target.
	const ref = capitalize(text);
	const linkNode = state.schema.text(ref, [
		state.schema.mark("link", {
			href: `wikiref:${encodeURIComponent(ref)}`,
		}),
	]);

	const tr = state.tr.replaceWith(from, to, linkNode);
	const posAfter = from + linkNode.nodeSize;
	tr.setSelection(TextSelection.create(tr.doc, posAfter));
	tr.setStoredMarks([]);
	dispatch(tr.scrollIntoView());
};
