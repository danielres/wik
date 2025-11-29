import { InputRule } from "@milkdown/prose/inputrules";
import { $inputRule } from "@milkdown/utils";
import { capitalize } from "../../utils";

export const inputRuleWikilink = (rootPath: string) =>
	$inputRule(
		() =>
			new InputRule(/\[\[([^\]]+)\]\]/g, (state, match, start, end) => {
				const [, pageName] = match;
				if (!pageName) return null;
				const pageSlug = encodeURIComponent(capitalize(pageName));

				const { schema } = state;

				const linkNode = schema.text(capitalize(pageName), [
					schema.mark("link", {
						href: `${rootPath}/${pageSlug}`,
					}),
				]);

				return state.tr.replaceWith(start, end, linkNode);
			}),
	);
