// assets/js/milkdown.ts
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
import {
	commonmark,
	selectTextNearPosCommand,
} from "@milkdown/kit/preset/commonmark";
import { gfm } from "@milkdown/kit/preset/gfm";
import { getMarkdown } from "@milkdown/utils";

import { setupBlockHandle } from "./milkdown/block-handle";
import { inputRuleWikilink } from "./milkdown/input-rule-wikilink";
import {
	slashMenuWikilinks,
	slashMenuWikilinksRegister,
	type SlashMenuWikilinksPage,
} from "./milkdown/slash-menu-wikilinks";
import { createSlashView } from "./milkdown/slash-view";
import { setupToolbar, toolbarTooltip } from "./milkdown/toolbar";

const slash = slashFactory("Commands");

const MilkdownEditor = {
	mounted() {
		const {
			markdown = "",
			editable: _editable,
			inputId,
			rootPath = "",
		} = this.el.dataset;

		const pagesJson = this.el.dataset.pagesJson;
		const editable = _editable !== undefined;

		let pages: SlashMenuWikilinksPage[] = [];

		if (pagesJson) {
			try {
				const parsed = JSON.parse(pagesJson) as Record<
					string,
					{ id: string; slug: string; title?: string; updated_at?: string }
				>;

				pages = Object.values(parsed).map((p, i) => ({
					id: String(p.id ?? i),
					label: String(p.title ?? p.slug ?? ""),
					slug: String(p.slug ?? ""),
					updatedAtMs: p.updated_at ? Date.parse(p.updated_at) : null,
				}));
			} catch (e) {
				console.error(
					"Invalid data-pages-json for MilkdownEditor:",
					e,
					pagesJson,
				);
			}
		}

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

				slashMenuWikilinksRegister(ctx, pages, rootPath);

				setupToolbar(ctx);
				setupBlockHandle(ctx, this.el as HTMLElement);

				ctx.set(listItemBlockConfig.key, {
					renderLabel: ({ label, listType, checked }) => {
						if (checked == null) {
							if (listType === "bullet") {
								return `<span class="ml-1 mr-1">-</span>`;
							}
							return label;
						}
					},
				});

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
			.use(slashMenuWikilinks)
			.use(toolbarTooltip)
			.use(cursorPlugin)
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
		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.focus();

		const doc = view.state.doc;
		let cursorPos = 0;
		doc.content.forEach((_node: any, offset: number) => {
			cursorPos = offset;
			return false;
		});

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
