import { $inputRule } from "@milkdown/utils";
import { InputRule } from "@milkdown/prose/inputrules";

export const inputRuleWikilink = (rootPath: string) =>
	$inputRule(
		() =>
			new InputRule(/\[\[([^\]]+)\]\]/g, (state, match, start, end) => {
				const [, pageName] = match;
				if (!pageName) return null;
				const pageSlug = encodeURIComponent(capitalize(pageName));

				const { schema } = state;

				const linkNode = schema.text(pageName, [
					schema.mark("link", {
						href: `${rootPath}/${pageSlug}`,
					}),
				]);

				return state.tr.replaceWith(start, end, linkNode);
			}),
	);

function capitalize(str: string): string {
	return str.charAt(0).toUpperCase() + str.substring(1).toLowerCase();
}
