import { editorViewCtx } from "@milkdown/core";
import type { Ctx } from "@milkdown/ctx";
import { capitalize } from "../../../utils";

export const toggleWikilinkCommand = (ctx: Ctx) => {
	const view = ctx.get(editorViewCtx);
	const { state, dispatch } = view;
	const { from, to } = state.selection;

	console.log({ from, to });
	// Get selected text
	const text = state.doc.textBetween(from, to);
	if (!text) return;

	// Create the link node directly (same as input rule)
	const rootPath = URL.parse(document.URL)
		?.pathname.split("/")
		.slice(0, 3)
		.join("/");

	console.log({ rootPath });
	const pageSlug = encodeURIComponent(capitalize(text));
	const linkNode = state.schema.text(capitalize(text), [
		state.schema.mark("link", {
			href: `${rootPath}/${pageSlug}`, // You'll need to pass rootPath
		}),
	]);

	console.log({ linkNode });
	// Replace selection with link node
	dispatch(state.tr.replaceWith(from, to, linkNode).scrollIntoView());
};
