// assets/js/milkdown/slash-menu-wikilinks.ts

import type { Ctx } from "@milkdown/ctx";
import { editorViewCtx } from "@milkdown/kit/core";
import { SlashProvider, slashFactory } from "@milkdown/kit/plugin/slash";
import { TextSelection } from "prosemirror-state";
import type { EditorView } from "prosemirror-view";

export type SlashMenuWikilinksPage = {
	id: string;
	label: string;
	slug: string;
	updatedAtMs: number | null;
};

export const slashMenuWikilinks = slashFactory("SLASH_MENU_WIKILINKS");

export function slashMenuWikilinksRegister(
	ctx: Ctx,
	pages: SlashMenuWikilinksPage[],
	rootPath: string,
) {
	ctx.set(slashMenuWikilinks.key, {
		view: (view: EditorView) =>
			new SlashMenuWikilinksView(ctx, view, pages, rootPath),
	});
}

/* ---------------- FUZZY MATCH ---------------- */

// Simple subsequence fuzzy score
function fuzzyScore(text: string, query: string): number {
	const t = text.toLowerCase();
	const q = query.toLowerCase();
	let ti = 0;
	let qi = 0;
	let score = 0;

	while (ti < t.length && qi < q.length) {
		if (t[ti] === q[qi]) {
			score++;
			qi++;
		}
		ti++;
	}
	return qi === q.length ? score : 0;
}

/* ---------------- VIEW ---------------- */
const RECENT_LIMIT = 5;

class SlashMenuWikilinksView {
	private ctx: Ctx;
	private view: EditorView;
	private allPages: SlashMenuWikilinksPage[];
	private filteredPages: SlashMenuWikilinksPage[] = [];
	private activeIndex = 0;
	private container: HTMLDivElement;
	private provider: SlashProvider;
	private isOpen = false;
	private keydownHandler: (e: KeyboardEvent) => void;
	private currentQuery = "";
	private rootPath: string;

	constructor(
		ctx: Ctx,
		view: EditorView,
		pages: SlashMenuWikilinksPage[],
		rootPath: string,
	) {
		this.ctx = ctx;
		this.view = view;
		this.allPages = pages.slice();
		this.rootPath = rootPath.replace(/\/+$/, "");

		this.container = document.createElement("div");
		this.container.className = "slash-menu-wikilinks-container";
		this.container.setAttribute("role", "listbox");
		this.container.setAttribute("id", "slash-menu-wikilinks");

		this.buildOptions();

		const self = this;

		this.provider = new SlashProvider({
			content: this.container,
			trigger: "[[",
			shouldShow(view: EditorView) {
				const currentText = this.getContent(view) as string | null;
				if (!currentText) {
					self.closeMenu();
					return false;
				}

				const match = currentText.match(/\[\[([^\]]*)$/);
				if (!match) {
					self.closeMenu();
					return false;
				}

				const query = match[1] || "";
				self.openMenu();
				self.updateQuery(query);

				return true;
			},
		});

		this.keydownHandler = (e) => this.onKeyDown(e);
		this.view.dom.addEventListener("keydown", this.keydownHandler, true);

		this.update(view);
	}

	update(view: EditorView, prevState?: any) {
		this.view = view;
		this.provider.update(view, prevState);
	}

	destroy() {
		this.view.dom.removeEventListener("keydown", this.keydownHandler, true);
		this.provider.destroy();
		this.container.remove();
	}

	/* ---------------- OPEN/CLOSE ---------------- */

	private openMenu() {
		if (this.isOpen) return;
		this.isOpen = true;

		const dom = this.view.dom as HTMLElement;
		dom.setAttribute("role", "combobox");
		dom.setAttribute("aria-expanded", "true");
		dom.setAttribute("aria-owns", "slash-menu-wikilinks");

		this.activeIndex = 0;
		this.updateActiveVisual();
	}

	private closeMenu() {
		if (!this.isOpen) return;
		this.isOpen = false;

		const dom = this.view.dom as HTMLElement;
		dom.setAttribute("aria-expanded", "false");
		dom.removeAttribute("aria-activedescendant");
	}

	/* ---------------- QUERY ---------------- */

	private updateQuery(query: string) {
		this.currentQuery = query;
		const q = query.trim();

		if (q === "") {
			// No search term yet → show most recently updated pages (top 5)
			this.filteredPages = this.allPages
				.slice()
				.sort((a, b) => {
					const av = a.updatedAtMs ?? 0;
					const bv = b.updatedAtMs ?? 0;
					return bv - av;
				})
				.slice(0, RECENT_LIMIT);
		} else {
			this.filteredPages = this.allPages
				.map((p) => ({
					page: p,
					score: fuzzyScore(p.label, q) || fuzzyScore(p.slug, q),
				}))
				.filter((x) => x.score > 0)
				.sort((a, b) => b.score - a.score)
				.map((x) => x.page)
				.slice(0, 20);
		}

		this.activeIndex = 0;
		this.buildOptions();
		this.updateActiveVisual();
	}

	/* ---------------- OPTIONS ---------------- */

	private buildOptions() {
		this.container.innerHTML = "";

		if (this.filteredPages.length === 0) {
			const empty = document.createElement("div");
			empty.className = "slash-menu-wikilinks-option-empty";
			empty.textContent = "No matching pages";
			this.container.appendChild(empty);
			return;
		}

		this.filteredPages.forEach((page, index) => {
			const element = document.createElement("div");
			element.className = "slash-menu-wikilinks-option";
			element.textContent = page.label;

			element.setAttribute("role", "option");
			element.setAttribute("data-index", String(index));
			element.setAttribute("data-page", page.slug);

			element.addEventListener("mousedown", (e) => {
				e.preventDefault();
				e.stopPropagation();
				this.selectOption(index);
			});

			this.container.appendChild(element);
		});
	}

	private updateActiveVisual() {
		const options = Array.from(
			this.container.querySelectorAll<HTMLElement>(
				".slash-menu-wikilinks-option",
			),
		);

		let activeId: string | null = null;

		options.forEach((el, idx) => {
			const isActive = idx === this.activeIndex;
			if (isActive) {
				if (!el.id) el.id = `slash-menu-wikilinks-option-${idx}`;
				activeId = el.id;
				el.classList.add("slash-menu-wikilinks-option-active");
				el.setAttribute("aria-selected", "true");
			} else {
				el.classList.remove("slash-menu-wikilinks-option-active");
				el.setAttribute("aria-selected", "false");
			}
		});

		const dom = this.view.dom as HTMLElement;
		if (this.isOpen && activeId) {
			dom.setAttribute("aria-activedescendant", activeId);
		} else {
			dom.removeAttribute("aria-activedescendant");
		}
	}

	/* ---------------- KEY EVENTS ---------------- */

	private onKeyDown(e: KeyboardEvent) {
		if (!this.isOpen) return;

		const hasOptions = this.filteredPages.length > 0;
		if (!hasOptions) return;

		const key = e.key;

		const isNext =
			key === "ArrowDown" || (e.ctrlKey && (key === "j" || key === "J"));

		const isPrev =
			key === "ArrowUp" || (e.ctrlKey && (key === "k" || key === "K"));

		if (isNext) {
			e.preventDefault();
			this.activeIndex = (this.activeIndex + 1) % this.filteredPages.length;
			this.updateActiveVisual();
			return;
		}

		if (isPrev) {
			e.preventDefault();
			this.activeIndex =
				(this.activeIndex - 1 + this.filteredPages.length) %
				this.filteredPages.length;
			this.updateActiveVisual();
			return;
		}

		switch (key) {
			case "Enter":
				e.preventDefault();
				this.selectOption(this.activeIndex);
				break;

			case "Escape":
				e.preventDefault();
				this.closeMenu();
				break;
		}
	}

	/* ---------------- INSERT LINK ---------------- */

	private selectOption(index: number) {
		const page = this.filteredPages[index];
		if (!page) return;

		const view = this.ctx.get(editorViewCtx);
		const { state } = view;
		const { from } = state.selection;

		const query = this.currentQuery;
		const deleteLen = query.length + 2; // "[[" + query
		const start = Math.max(0, from - deleteLen);

		const { schema } = state;
		const linkMark = schema.marks["link"];
		const href = `${this.rootPath}/${encodeURIComponent(page.slug)}`;
		const linkNode = schema.text(page.label, [linkMark.create({ href })]);

		const tr = state.tr.replaceWith(start, from, linkNode);

		// Move cursor after the inserted link and clear stored marks
		const posAfter = start + linkNode.nodeSize;
		tr.setSelection(TextSelection.create(tr.doc, posAfter));
		tr.setStoredMarks([]);

		view.dispatch(tr);

		this.closeMenu();
	}
}
