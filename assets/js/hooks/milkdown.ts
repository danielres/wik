// milkdown-editor.ts
import { selectTextNearPosCommand } from "@milkdown/kit/preset/commonmark";
import { tableBlock } from "@milkdown/components/table-block";
import { CommandManager, commandsCtx, editorViewCtx } from "@milkdown/core";
import type { Ctx, SliceType } from "@milkdown/ctx";
import {
	listItemBlockComponent,
	listItemBlockConfig,
} from "@milkdown/kit/component/list-item-block";
import {
	DefaultValue,
	defaultValueCtx,
	Editor,
	rootCtx,
} from "@milkdown/kit/core";
import { block } from "@milkdown/kit/plugin/block";
import {
	cursor as cursorPlugin,
	dropIndicatorConfig,
} from "@milkdown/kit/plugin/cursor";
import { history } from "@milkdown/kit/plugin/history";
import { slashFactory } from "@milkdown/kit/plugin/slash";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { gfm } from "@milkdown/kit/preset/gfm";
import { getMarkdown } from "@milkdown/utils";

import { setupBlockHandle } from "./milkdown/block-handle";
import { inputRuleWikilink } from "./milkdown/input-rule-wikilink";
import { createSlashView } from "./milkdown/slash-view";
import { setupToolbar, toolbarTooltip } from "./milkdown/toolbar";
import { EditorView } from "@milkdown/kit/prose/view";
import {
	configureWikiLinkMenu,
	insertWikiLinkCommand,
	wikiLinkMenu,
} from "./milkdown/slash-pages";

const slash = slashFactory("Commands");

const MilkdownEditor = {
	mounted() {
		const {
			markdown = "",
			editable: _editable,
			inputId,
			rootPath,
		} = this.el.dataset;
		const editable = _editable !== undefined;
		this.hiddenInput = inputId ? document.getElementById(inputId) : null;
		this.form = this.el.closest("form");

		Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, this.el);
				ctx.set(defaultValueCtx, markdown);

				ctx.set(slash.key, {
					view: createSlashView(this.el, (fn: (ctx: Ctx) => void) => {
						if (!this.editorInstance) return;
						this.editorInstance.action(fn);
					}),
				});

				configureWikiLinkMenu(ctx);

				setupToolbar(ctx);
				setupBlockHandle(ctx, this.el as HTMLElement);

				ctx.set(listItemBlockConfig.key, {
					renderLabel: ({ label, listType, checked, readonly: _readonly }) => {
						if (checked == null) {
							if (listType === "bullet")
								return `<span class="ml-1 mr-1">-</span>`;
							return label;
						}
					},
				});

				// Drop indicator config (line shown while dragging)
				ctx.update(dropIndicatorConfig.key, () => ({
					width: 1,
				}));
			})
			.use(commonmark)
			.use(gfm)
			.use(history)
			.use(listItemBlockComponent)
			.use(tableBlock)
			.use(block)
			.use(slash)
			.use(insertWikiLinkCommand) // Add the wikilink command
			.use(wikiLinkMenu) // Add the wikilink menu plugin
			.use(toolbarTooltip)
			.use(cursorPlugin) // gap cursor + drop indicator
			.use(inputRuleWikilink(rootPath))
			.create()
			.then((editor) => {
				this.editorInstance = editor;
				this.setEditable(editable);
				this.setupFormSync();
				if (editable) this.setFocusAndCursorPos(editor);
			});
	},

	setFocusAndCursorPos() {
		// Autofocus
		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.focus();

		// Calculate position for second node
		const doc = view.state.doc;
		let cursorPos = 0;
		doc.content.forEach((_node: any, offset: number) => {
			cursorPos = offset;
			return false; // stop iteration
		});

		// Set cursor position
		this.editorInstance.action(
			(ctx: { get: (arg0: SliceType<CommandManager, "commands">) => any }) => {
				const commands = ctx.get(commandsCtx);
				commands.call(selectTextNearPosCommand.key, { pos: cursorPos });
			},
		);
	},

	setEditable(editable: any) {
		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.props.editable = () => editable;
		view.updateState(view.state);
	},

	setupFormSync() {
		if (this.form && this.hiddenInput) {
			this.handleSubmit = () => {
				this.hiddenInput.value = this.editorInstance.action(getMarkdown());
				this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
			};
			this.form.addEventListener("submit", this.handleSubmit);
		}
	},

	updated() {
		if (!this.editorInstance) return;

		this.setEditable(this.el.dataset.editable !== undefined);

		const markdown = this.el.dataset.markdown || "";
		if (markdown !== this.lastMarkdown) {
			this.editorInstance.action(
				(ctx: {
					set: (key: SliceType<DefaultValue, "defaultValue">, v: any) => any;
				}) => ctx.set(defaultValueCtx, markdown),
			);
			this.lastMarkdown = markdown;
		}
	},

	destroyed() {
		this.form?.removeEventListener("submit", this.handleSubmit);
		this.editorInstance = null;
		this.form = null;
		this.hiddenInput = null;
	},
};

export default MilkdownEditor;
