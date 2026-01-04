import { editorViewCtx } from "@milkdown/core";
import type { Ctx } from "@milkdown/ctx";
import { TextSelection } from "prosemirror-state";

export const toggleWikilinkCommand = (ctx: Ctx) => {
	const view = ctx.get(editorViewCtx);
	const { state, dispatch } = view;
	const { from, to } = state.selection;

	const text = state.doc.textBetween(from, to).trim();
	if (!text) return;

	const wikilinkType = state.schema.nodes["wikilink"];
	if (!wikilinkType) return;

	const linkNode = wikilinkType.create({ path: text });

	const tr = state.tr.replaceWith(from, to, linkNode);
	const posAfter = from + linkNode.nodeSize;
	tr.setSelection(TextSelection.create(tr.doc, posAfter));
	tr.setStoredMarks([]);
	dispatch(tr.scrollIntoView());
};
