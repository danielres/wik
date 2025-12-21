import { InputRule } from "@milkdown/prose/inputrules";
import { $inputRule } from "@milkdown/utils";
import { TextSelection } from "prosemirror-state";
import { capitalize } from "../../utils";

export const inputRuleWikilink = $inputRule(
	() =>
		new InputRule(/\[\[([^\]]+)\]\]/g, (state, match, start, end) => {
			const [, pageName] = match;
			if (!pageName) return null;
			const ref = capitalize(pageName);

			const { schema } = state;

			const linkNode = schema.text(capitalize(pageName), [
				schema.mark("link", {
					href: `wikiref:${encodeURIComponent(ref)}`,
				}),
			]);

			const tr = state.tr.replaceWith(start, end, linkNode);
			const posAfter = start + linkNode.nodeSize;
			tr.setSelection(TextSelection.create(tr.doc, posAfter));
			tr.setStoredMarks([]);
			return tr;
		}),
);
