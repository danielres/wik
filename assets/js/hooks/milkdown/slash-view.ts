// milkdown-slash-view.ts
import type { Ctx } from "@milkdown/ctx";
import { editorViewCtx } from "@milkdown/kit/core";
import { SlashProvider } from "@milkdown/kit/plugin/slash";
import { createCodeBlockCommand } from "@milkdown/kit/preset/commonmark";
import { insertTableCommand } from "@milkdown/kit/preset/gfm";
import { callCommand } from "@milkdown/kit/utils";

type EditorAction = (fn: (ctx: Ctx) => void) => void;

export const createSlashView =
	(rootEl: HTMLElement, editorAction: EditorAction) => (_view: any) => {
		const container = document.createElement("div");
		container.className =
			"absolute hidden data-[show='true']:grid w-64 gap-1 p-2 bg-base-300 rounded";
		rootEl.appendChild(container);

		const provider = new SlashProvider({
			content: container,
		});

		const makeSlashHandler =
			(commandKey: any, payload?: any) => (e: MouseEvent | KeyboardEvent) => {
				e.preventDefault();
				e.stopPropagation();

				editorAction((ctx) => {
					const view = ctx.get(editorViewCtx);
					const { dispatch, state } = view;
					const { tr, selection } = state;
					const { from } = selection;

					// delete the trigger `/`
					dispatch(tr.deleteRange(from - 1, from));

					return payload
						? callCommand(commandKey, payload)(ctx)
						: callCommand(commandKey)(ctx);
				});
			};

		const createButton = (label: string, handler: (e: any) => void) => {
			const button = document.createElement("button");
			button.type = "button";
			button.textContent = label;
			button.className =
				"btn btn-base hover:bg-base-100 border border-base-300 shadow";
			button.addEventListener("mousedown", handler);
			container.appendChild(button);
			return button;
		};

		const handleCodeBlock = makeSlashHandler(createCodeBlockCommand.key);
		const handleTable = makeSlashHandler(insertTableCommand.key);

		const buttonCode = createButton("Code Block", handleCodeBlock);
		const buttonTable = createButton("Table", handleTable);

		return {
			update: (updatedView: any, prevState: any) => {
				provider.update(updatedView, prevState);
			},
			destroy: () => {
				provider.destroy();
				buttonCode.removeEventListener("mousedown", handleCodeBlock);
				buttonTable.removeEventListener("mousedown", handleTable);
				container.remove();
			},
		};
	};
