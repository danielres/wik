import { $inputRule } from "@milkdown/utils";
import { InputRule } from "@milkdown/prose/inputrules";

export const inputRuleWikilink = (rootPath: string) =>
	$inputRule(
		() =>
			new InputRule(/\[\[([^\]]+)\]\]/g, (state, match, start, end) => {
				const [, pageName] = match;
				if (!pageName) return null;

				// Create a link node for the wiki link
				const { schema } = state;
				const linkNode = schema.text(pageName, [
					schema.mark("link", { href: `${rootPath}/${pageName}` }),
				]);

				return state.tr.replaceWith(start, end, linkNode);
			}),
	);
