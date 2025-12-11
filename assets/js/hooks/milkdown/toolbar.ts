// assets/js/milkdown/toolbar.ts
import type { Ctx } from "@milkdown/ctx";
import { commandsCtx, editorCtx, EditorStatus } from "@milkdown/kit/core";
import { tooltipFactory, TooltipProvider } from "@milkdown/kit/plugin/tooltip";
import {
	emphasisSchema,
	inlineCodeSchema,
	isMarkSelectedCommand,
	strongSchema,
	toggleEmphasisCommand,
	toggleInlineCodeCommand,
	toggleStrongCommand,
} from "@milkdown/kit/preset/commonmark";
import {
	strikethroughSchema,
	toggleStrikethroughCommand,
} from "@milkdown/kit/preset/gfm";
import type { PluginView } from "@milkdown/kit/prose/state";
import {
	EditorState,
	Selection,
	TextSelection,
} from "@milkdown/kit/prose/state";
import type { EditorView } from "@milkdown/kit/prose/view";
import { toggleLinkCommand } from "@milkdown/components/link-tooltip";
import { linkSchema } from "@milkdown/kit/preset/commonmark";
import { toggleWikilinkCommand } from "./toolbar/command-toggle-wiki-link";

// 1) Create a tooltip plugin
export const toolbarTooltip = tooltipFactory("WIK_TOOLBAR");

// 2) Simple ToolbarView that builds DOM buttons and wires them to commands
class ToolbarView implements PluginView {
	private ctx: Ctx;
	private tooltipProvider: TooltipProvider;
	private content: HTMLElement;
	private buttons: {
		el: HTMLButtonElement;
		active: (ctx: Ctx) => boolean;
	}[] = [];

	constructor(ctx: Ctx, view: EditorView) {
		this.ctx = ctx;

		const content = document.createElement("div");
		content.className = "milkdown-toolbar";

		// Define toolbar items
		const items: {
			label: string;
			title: string;
			active: (ctx: Ctx) => boolean;
			run: (ctx: Ctx) => void;
		}[] = [
			{
				label: "B",
				title: "Bold",
				active: (ctx) => {
					const commands = ctx.get(commandsCtx);
					return commands.call(
						isMarkSelectedCommand.key,
						strongSchema.type(ctx),
					);
				},
				run: (ctx) => {
					const commands = ctx.get(commandsCtx);
					commands.call(toggleStrongCommand.key);
				},
			},
			{
				label: "I",
				title: "Italic",
				active: (ctx) => {
					const commands = ctx.get(commandsCtx);
					return commands.call(
						isMarkSelectedCommand.key,
						emphasisSchema.type(ctx),
					);
				},
				run: (ctx) => {
					const commands = ctx.get(commandsCtx);
					commands.call(toggleEmphasisCommand.key);
				},
			},
			{
				label: "S",
				title: "Strikethrough",
				active: (ctx) => {
					const commands = ctx.get(commandsCtx);
					return commands.call(
						isMarkSelectedCommand.key,
						strikethroughSchema.type(ctx),
					);
				},
				run: (ctx) => {
					const commands = ctx.get(commandsCtx);
					commands.call(toggleStrikethroughCommand.key);
				},
			},
			{
				label: "</>",
				title: "Inline code",
				active: (ctx) => {
					const commands = ctx.get(commandsCtx);
					return commands.call(
						isMarkSelectedCommand.key,
						inlineCodeSchema.type(ctx),
					);
				},
				run: (ctx) => {
					const commands = ctx.get(commandsCtx);
					commands.call(toggleInlineCodeCommand.key);
				},
			},

			{
				label: "W",
				title: "Wikilink",
				active: () => false, // Wikilinks are converted to links by input rule
				run: (ctx) => {
					const editor = ctx.get(editorCtx);
					if (editor.status !== EditorStatus.Created) return;
					toggleWikilinkCommand(ctx);
				},
			},
			{
				label: "🔗",
				title: "Insert/edit link",
				active: (ctx) => {
					const commands = ctx.get(commandsCtx);
					return commands.call(
						isMarkSelectedCommand.key,
						linkSchema.type(ctx),
					);
				},
				run: (ctx) => {
					const editor = ctx.get(editorCtx);
					if (editor.status !== EditorStatus.Created) return;
					const commands = ctx.get(commandsCtx);
					commands.call(toggleLinkCommand.key);
				},
			},
		];

		// Build DOM buttons
		items.forEach((item, index) => {
			if (index > 0) {
				// divider
				const divider = document.createElement("div");
				divider.className = "w-px h-4 my-auto bg-zinc-700";
				content.appendChild(divider);
			}

			const btn = document.createElement("button");
			btn.type = "button";
			btn.textContent = item.label;
			btn.title = item.title;
			btn.className =
				"toolbar-item px-1 rounded hover:bg-zinc-700/80 data-[active=true]:bg-zinc-600";

			btn.addEventListener("mousedown", (e) => {
				e.preventDefault();
				// ensure editor created
				const editor = ctx.get(editorCtx);
				if (editor.status !== EditorStatus.Created) return;
				item.run(ctx);
			});

			content.appendChild(btn);
			this.buttons.push({
				el: btn,
				active: item.active,
			});
		});

		this.content = content;

		// TooltipProvider controls positioning & visibility
		this.tooltipProvider = new TooltipProvider({
			content: this.content,
			debounce: 20,
			offset: 10,
			shouldShow(view: EditorView) {
				const { doc, selection } = view.state;
				const { empty, from, to } = selection as Selection;

				const isEmptyTextBlock =
					!doc.textBetween(from, to).length &&
					selection instanceof TextSelection;

				const isNotTextBlock = !(selection instanceof TextSelection);

				const activeElement = (view.dom.getRootNode() as ShadowRoot | Document)
					.activeElement;
				const isTooltipChildren = content.contains(activeElement);

				const notHasFocus = !view.hasFocus() && !isTooltipChildren;

				const isReadonly = !view.editable;

				if (
					notHasFocus ||
					isNotTextBlock ||
					empty ||
					isEmptyTextBlock ||
					isReadonly
				)
					return false;

				return true;
			},
		});

		this.tooltipProvider.update(view);
		this.updateActiveState();
	}

	// Update gets called on selection/doc changes
	update = (view: EditorView, prevState?: EditorState) => {
		this.tooltipProvider.update(view, prevState);
		this.updateActiveState();
	};

	destroy = () => {
		this.tooltipProvider.destroy();
		this.content.remove();
	};

	private updateActiveState() {
		const editor = this.ctx.get(editorCtx);
		if (editor.status !== EditorStatus.Created) return;

		this.buttons.forEach((btn) => {
			const active = btn.active(this.ctx);
			btn.el.dataset.active = active ? "true" : "false";
		});
	}
}

// Helper to wire into ctx
export function setupToolbar(ctx: Ctx) {
	ctx.set(toolbarTooltip.key, {
		view: (view: EditorView) => new ToolbarView(ctx, view),
	});
}
