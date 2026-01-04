import { InputRule } from "@milkdown/prose/inputrules";
import { $inputRule } from "@milkdown/utils";
import { TextSelection } from "prosemirror-state";

export const inputRuleWikilink = $inputRule(
	() =>
		new InputRule(/\[\[([^\]]+)\]\]/g, (state, match, start, end) => {
			const [, rawPath] = match;
			const path = String(rawPath || "").trim();
			if (!path) return null;

			const { schema } = state;
			const wikilinkType = schema.nodes["wikilink"];
			if (!wikilinkType) return null;

			const linkNode = wikilinkType.create({ path });

			const tr = state.tr.replaceWith(start, end, linkNode);
			const posAfter = start + linkNode.nodeSize;
			tr.setSelection(TextSelection.create(tr.doc, posAfter));
			tr.setStoredMarks([]);
			return tr;
		}),
);
