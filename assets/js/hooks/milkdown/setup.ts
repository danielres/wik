import {
	configureLinkTooltip,
	linkTooltipPlugin,
} from "@milkdown/components/link-tooltip";
import { tableBlock } from "@milkdown/components/table-block";
import type { Ctx } from "@milkdown/ctx";
import {
	splitEditing,
	splitEditingOptionsCtx,
} from "@milkdown-lab/plugin-split-editing";
import {
	listItemBlockComponent,
	listItemBlockConfig,
} from "@milkdown/kit/component/list-item-block";
import {
	defaultValueCtx,
	Editor,
	editorViewCtx,
	prosePluginsCtx,
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
import { collab, collabServiceCtx } from "@milkdown/plugin-collab";
import { clipboard } from "@milkdown/kit/plugin/clipboard";
import { getMarkdown } from "@milkdown/utils";
import { setupBlockHandle } from "./block-handle";
import { embedSchema, remarkEmbedDirective, remarkEmbedPlugin } from "./embed-node";
import { embedView } from "./embed-view";
import { inputRuleWikilink } from "./input-rule-wikilink";
import { overrideHeadingSchema } from "./override-heading-schema";
import {
	slashMenuWikilinks,
	slashMenuWikilinksRegister,
	type SlashMenuWikilinksPage,
} from "./slash-menus/slash-menu-wikilinks";
import { createSlashMenu } from "./slash-menus/slash-menu";
import { overrideTableSchema, sanitizeDocPlugin } from "./sanitize-doc";
import { ensureTitleHeadingPlugin } from "./ensure-title-heading";
import { wikilinkPlugin } from "./wikilink-plugin";
import {
	remarkWikilinkPlugin,
	wikilinkConfig,
	wikilinkSchema,
	wikilinkView,
} from "./wikilink-node";
import { createTagBadgePlugin } from "./tag-badge-plugin";
import { setupToolbar, toolbarTooltip } from "./toolbar";
import { configurePasteHandlers } from "./utils/paste-handlers";
import {
	createSplitEditorEditableExtension,
	splitEditorHighlighting,
} from "./split-editor/custom-highlighting";

const slash = slashFactory("Commands");

type SetupOpts = {
	root: HTMLElement;
	markdown: string;
	pages: SlashMenuWikilinksPage[];
	rootPath: string;
	isStatic: boolean;
	splitEditorEditableRef?: { value: boolean };
	wikilinks?: {
		getPageById: (
			id: string,
		) => { id: string; slug: string; title: string } | null;
		resolveRef: (
			title: string,
		) => Promise<{ id: string; slug: string; title: string } | null>;
	};
};

export async function createMilkdownEditor({
	root,
	markdown,
	pages,
	rootPath,
	isStatic,
	splitEditorEditableRef,
	wikilinks,
}: SetupOpts) {
	return (
		Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, root);
				ctx.set(wikilinkConfig.key, {
					rootPath,
					getPageById: wikilinks?.getPageById ?? (() => null),
				});

				if (isStatic) {
					ctx.set(defaultValueCtx, markdown);
				}

				ctx.set(slash.key, {
					view: createSlashMenu(root, (fn: (ctx: Ctx) => void) => {
						if (!editorInstance) return;
						editorInstance.action(fn);
					}),
				});

				slashMenuWikilinksRegister(ctx, pages);

				setupToolbar(ctx);
				setupBlockHandle(ctx, root as HTMLElement);

				const tagRootPath = rootPath.replace(/\/wiki\/?$/, "/tags");

				ctx.update(prosePluginsCtx, (plugins) =>
					plugins.concat(createTagBadgePlugin(tagRootPath)),
				);

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

				ctx.set(splitEditingOptionsCtx.key, {
					extensions: [
						splitEditorHighlighting,
						...(splitEditorEditableRef
							? [createSplitEditorEditableExtension(splitEditorEditableRef)]
							: []),
					],
				});

				configurePasteHandlers(ctx, rootPath);

				ctx.update(dropIndicatorConfig.key, () => ({
					width: 1,
				}));
			})

			.config(configureLinkTooltip)
			.use(wikilinkConfig)
			.use(remarkWikilinkPlugin)
			.use(remarkEmbedDirective)
			.use(remarkEmbedPlugin)
			.use(commonmark)
			.use(linkTooltipPlugin)
			.use(gfm)
			.use(wikilinkSchema)
			.use(embedSchema)
			.use(embedView)
			.use(wikilinkView)
			.use(overrideHeadingSchema)
			.use(overrideTableSchema)
			.use(history)
			.use(collab)
			.use(listItemBlockComponent)
			.use(tableBlock)
			.use(block)
			.use(slash)
			.use(slashMenuWikilinks)
			.use(toolbarTooltip)
			.use(cursorPlugin)
			.use(clipboard)
			.use(inputRuleWikilink)
			.use(splitEditing)
			// Ensure the sanitizer is appended after all other ProseMirror plugins.
			.config((ctx) => {
				ctx.update(prosePluginsCtx, (plugins) =>
					plugins.concat(
						sanitizeDocPlugin,
						ensureTitleHeadingPlugin({ rootEl: root }),
						wikilinks
							? wikilinkPlugin({
									resolveRef: wikilinks.resolveRef,
								})
							: [],
					),
				);
			})
			.create()
			.then((editor) => {
				setEditorInstance(editor);
				return { editor, collabService: editor.ctx.get(collabServiceCtx) };
			})
	);
}

let editorInstance: any = null;

function setEditorInstance(instance: any) {
	editorInstance = instance;
}

export { collabServiceCtx, editorViewCtx, getMarkdown };
