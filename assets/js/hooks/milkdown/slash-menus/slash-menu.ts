// milkdown-slash-menu.ts
import type { Ctx } from "@milkdown/ctx";
import { editorViewCtx } from "@milkdown/kit/core";
import { callCommand } from "@milkdown/kit/utils";
import { NodeSelection, type Transaction } from "prosemirror-state";
import type { EditorView } from "prosemirror-view";
import {
	createSlashMenuView,
	type SlashMenuItem,
} from "./components/slash-menu-view";
import { isSelectionInHeading } from "../utils/selection";

type EditorAction = (fn: (ctx: Ctx) => void) => void;

type CommandItem = SlashMenuItem & { commandId?: string; matchText: string };

const COMMAND_ITEMS: CommandItem[] = [
	{
		id: "code_block",
		label: "Code Block",
		commandId: "CreateCodeBlock",
		matchText: "code block code",
	},
	{
		id: "table",
		label: "Table",
		commandId: "InsertTable",
		matchText: "table",
	},
	{
		id: "embed",
		label: "Embed",
		matchText: "embed video youtube soundcloud",
	},
];

function filterCommands(query: string): CommandItem[] {
	const q = query.trim().toLowerCase();
	if (q === "") return COMMAND_ITEMS;
	return COMMAND_ITEMS.filter((c) => c.matchText.includes(q));
}

function isAtRoot(view: EditorView) {
	const $pos = view.state.selection.$from;
	// depth 1 means direct child of doc; depth 0 is the doc itself
	return $pos.depth <= 1;
}

export const createSlashMenu = (
	rootEl: HTMLElement,
	editorAction: EditorAction,
) =>
	createSlashMenuView<CommandItem>({
		root: rootEl,
		containerId: "slash-menu",
		containerClassName:
			"milkdown-slash-menu hidden absolute z-50 w-64 max-h-60 overflow-y-auto bg-base-300 border border-base-300 rounded shadow-lg p-2 grid gap-1 data-[show='true']:grid",
		optionClassName:
			"px-2 py-1 cursor-pointer rounded bg-base-200 border border-base-300 shadow-sm hover:bg-base-100 transition-colors text-base-content/70",
		optionActiveClassName: "bg-primary/20 text-primary-content border-primary",
		debounceMs: 0,
		allow: (view) => isAtRoot(view) && !isSelectionInHeading(view),
		getQuery: (textBlockContent) => {
			const match = textBlockContent.match(/(?:^|\s)\/([^\s]*)$/);
			return match ? (match[1] ?? "") : null;
		},
		getItems: (query) => filterCommands(query),
		onSelect: (item, { query }) => {
			editorAction((ctx) => {
				const view = ctx.get(editorViewCtx);
				const { dispatch, state } = view;
				const { from } = state.selection;
				const deleteLen = query.length + 1; // "/" + query
				const start = Math.max(0, from - deleteLen);
				const tr = state.tr.deleteRange(start, from);

				if (item.id === "embed") {
					insertEmbedPlaceholder(view, tr, from);
					return;
				}

				dispatch(tr);
				if (item.commandId) {
					callCommand(item.commandId)(ctx);
				}
			});
		},
	});

function insertEmbedPlaceholder(
	view: EditorView,
	tr: Transaction,
	from: number,
) {
	const embedType = view.state.schema.nodes["embed"];
	if (!embedType) {
		console.error("Embed node not found in schema");
		return;
	}

	const embedNode = embedType.create({ src: "", provider: "" });
	const mappedFrom = Math.min(tr.doc.content.size, tr.mapping.map(from));
	const $pos = tr.doc.resolve(mappedFrom);

	let insertPos = mappedFrom;

	if ($pos.parent.isTextblock && $pos.depth > 0) {
		const parentStart = $pos.before();
		const parentEnd = $pos.after();
		const parentText = $pos.parent.textContent.trim();

		if (parentText === "") {
			tr.replaceWith(parentStart, parentEnd, embedNode);
			insertPos = parentStart;
		} else {
			insertPos = parentEnd;
			tr.insert(insertPos, embedNode);
		}
	} else {
		tr.insert(insertPos, embedNode);
	}

	if (tr.doc.nodeAt(insertPos)) {
		tr.setSelection(NodeSelection.create(tr.doc, insertPos));
	}
	tr.setStoredMarks([]);
	view.dispatch(tr.scrollIntoView());
}
