// milkdown/slash-pages.ts
import type { Ctx } from "@milkdown/ctx";
import { editorViewCtx, commandsCtx } from "@milkdown/kit/core";
import { SlashProvider, slashFactory } from "@milkdown/kit/plugin/slash";
import { createCmdKey } from "@milkdown/kit/core";
import { $command } from "@milkdown/kit/utils";

// Command for inserting wikilinks
const insertWikiLinkCommandKey = createCmdKey<string>("InsertWikiLink");

export const insertWikiLinkCommand = $command(
	"InsertWikiLink",
	(ctx) => (pageName?: string) => {
		// Make pageName optional
		if (!pageName) return false; // Handle undefined case

		const view = ctx.get(editorViewCtx);
		const { dispatch, state } = view;
		const { tr, selection } = state;
		const { from } = selection;

		// Delete the trigger '[[' (2 characters)
		dispatch(tr.deleteRange(from - 2, from));

		// Insert the wikilink
		view.dispatch(tr.insertText(`[[${pageName}]]`));
		return true;
	},
);

// Hardcoded wiki pages
const WIKI_PAGES = [
	{ label: "Home", page: "Home" },
	{ label: "About", page: "About" },
	{ label: "Documentation", page: "Documentation" },
	{ label: "Contact", page: "Contact" },
	{ label: "Help", page: "Help" },
];

export const wikiLinkMenu = slashFactory("WIKI_LINK");

export const configureWikiLinkMenu = (ctx: Ctx) => {
	ctx.set(wikiLinkMenu.key, {
		view: (view) => new WikiLinkMenuView(ctx, view),
	});
};

class WikiLinkMenuView {
	private container: HTMLElement;
	private provider: SlashProvider;

	constructor(
		private ctx: Ctx,
		view: any,
	) {
		// Create menu container
		this.container = document.createElement("div");
		this.container.className = "milkdown-slash-view"; // Use existing class

		// Create buttons for each hardcoded page
		WIKI_PAGES.forEach(({ label, page }) => {
			const button = document.createElement("button");
			button.textContent = label;
			button.className = "wikilink-option";
			button.addEventListener("mousedown", (e) => {
				e.preventDefault();
				e.stopPropagation();

				const commands = this.ctx.get(commandsCtx);
				commands.call(insertWikiLinkCommandKey, page);
			});
			this.container.appendChild(button);
		});

		// Configure the slash provider
		this.provider = new SlashProvider({
			content: this.container,
			trigger: "[[",
			shouldShow: function (view) {
				const currentText = this.getContent(view);
				console.log("Current text:", currentText); // Debug log
				console.log("Ends with [[?:", currentText?.endsWith("[[")); // Debug log
				return currentText?.endsWith("[[") ?? false;
			},
		});
		this.update(view);
	}

	update = (view: any, prevState?: any) => {
		this.provider.update(view, prevState);
	};

	destroy = () => {
		this.provider.destroy();
		this.container.remove();
	};
}
