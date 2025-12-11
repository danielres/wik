import {
	configureLinkTooltip,
	linkTooltipPlugin,
	linkTooltipConfig,
} from "@milkdown/components/link-tooltip";
import { defaultValueCtx, Editor } from "@milkdown/kit/core";
import { commonmark, linkSchema } from "@milkdown/kit/preset/commonmark";
import { tableBlock } from "@milkdown/components/table-block";
import { editorViewCtx, prosePluginsCtx } from "@milkdown/core";
import type { Ctx } from "@milkdown/ctx";
import {
	listItemBlockComponent,
	listItemBlockConfig,
} from "@milkdown/kit/component/list-item-block";
import { defaultValueCtx, Editor, rootCtx } from "@milkdown/kit/core";
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
import { getMarkdown } from "@milkdown/utils";
import { setupBlockHandle } from "./block-handle";
import { inputRuleWikilink } from "./input-rule-wikilink";
import { createTagBadgePlugin } from "./tag-badge-plugin";
import {
	slashMenuWikilinks,
	slashMenuWikilinksRegister,
	type SlashMenuWikilinksPage,
} from "./slash-menu-wikilinks";
import { createSlashView } from "./slash-view";
import { setupToolbar, toolbarTooltip } from "./toolbar";
import { configurePasteHandlers } from "./utils/paste-handlers";

const slash = slashFactory("Commands");

type SetupOpts = {
	root: HTMLElement;
	markdown: string;
	pages: SlashMenuWikilinksPage[];
	rootPath: string;
	isStatic: boolean;
};

export async function createMilkdownEditor({
	root,
	markdown,
	pages,
	rootPath,
	isStatic,
}: SetupOpts) {
	return Editor.make()
		.config((ctx) => {
			ctx.set(rootCtx, root);

			if (isStatic) {
				ctx.set(defaultValueCtx, markdown);
			}

			ctx.set(slash.key, {
				view: createSlashView(root, (fn: (ctx: Ctx) => void) => {
					if (!editorInstance) return;
					editorInstance.action(fn);
				}),
			});

			slashMenuWikilinksRegister(ctx, pages, rootPath);

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

			configurePasteHandlers(ctx, rootPath);

			ctx.update(dropIndicatorConfig.key, () => ({
				width: 1,
			}));
		})

		.config(configureLinkTooltip)
		.use(commonmark)
		.use(linkTooltipPlugin)
		.use(gfm)
		.use(history)
		.use(collab)
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
			setEditorInstance(editor);
			return { editor, collabService: editor.ctx.get(collabServiceCtx) };
		});
}

let editorInstance: any = null;

function setEditorInstance(instance: any) {
	editorInstance = instance;
}

export { collabServiceCtx, editorViewCtx, getMarkdown };
