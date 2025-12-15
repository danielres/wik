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
		container.className = "milkdown-slash-view";
		rootEl.appendChild(container);

		const provider = new SlashProvider({
			content: container,
		});

		const emptyState = document.createElement("div");
		emptyState.className = "slash-empty";
		emptyState.textContent = "No actions available";
		emptyState.style.display = "none";
		container.appendChild(emptyState);

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
			button.className = "";
			button.addEventListener("mousedown", handler);
			container.appendChild(button);
			return button;
		};

		const isAtRoot = (view: any) => {
			const $pos = view.state.selection.$from;
			// depth 1 means direct child of doc; depth 0 is the doc itself
			return $pos.depth <= 1;
		};

		const handleCodeBlock = (e: any) => {
			editorAction((ctx) => {
				const view = ctx.get(editorViewCtx);
				if (!isAtRoot(view)) return;
			});
			makeSlashHandler(createCodeBlockCommand.key)(e);
		};

		const handleTable = (e: any) => {
			editorAction((ctx) => {
				const view = ctx.get(editorViewCtx);
				if (!isAtRoot(view)) return;
			});
			makeSlashHandler(insertTableCommand.key)(e);
		};

		const buttonCode = createButton("Code Block", handleCodeBlock);
		const buttonTable = createButton("Table", handleTable);

		const updateVisibility = (atRoot: boolean) => {
			buttonCode.style.display = atRoot ? "" : "none";
			buttonTable.style.display = atRoot ? "" : "none";
			const anyVisible = atRoot; // only these two actions for now
			emptyState.style.display = anyVisible ? "none" : "";
		};

		return {
			update: (updatedView: any, prevState: any) => {
				provider.update(updatedView, prevState);
				const atRoot = isAtRoot(updatedView);
				updateVisibility(atRoot);
			},
			destroy: () => {
				provider.destroy();
				buttonCode.removeEventListener("mousedown", handleCodeBlock);
				buttonTable.removeEventListener("mousedown", handleTable);
				container.remove();
			},
		};
	};
