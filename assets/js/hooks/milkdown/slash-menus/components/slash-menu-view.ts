import type { EditorState } from "@milkdown/kit/prose/state";
import { SlashProvider } from "@milkdown/kit/plugin/slash";
import type { EditorView } from "prosemirror-view";

export type SlashMenuItem = { id: string; label: string };

type Options<TItem extends SlashMenuItem> = {
	root?: HTMLElement;
	containerId: string;
	containerClassName: string;
	optionClassName: string;
	optionActiveClassName: string;
	debounceMs?: number;
	allow?: (view: EditorView) => boolean;
	getQuery: (textBlockContent: string) => string | null;
	getItems: (query: string) => TItem[];
	onSelect: (item: TItem, api: { view: EditorView; query: string }) => void;
};

export function createSlashMenuView<TItem extends SlashMenuItem>(
	options: Options<TItem>,
) {
	return (view: EditorView) => new SlashMenuView<TItem>(view, options);
}

class SlashMenuView<TItem extends SlashMenuItem> {
	private view: EditorView;
	private provider: SlashProvider;
	private container: HTMLDivElement;
	private keydownHandler: (e: KeyboardEvent) => void;

	private isOpen = false;
	private activeIndex = 0;
	private items: TItem[] = [];
	private currentQuery = "";

	private containerId: string;
	private optionClassName: string;
	private optionActiveClassName: string;
	private onSelect: Options<TItem>["onSelect"];

	constructor(view: EditorView, options: Options<TItem>) {
		this.view = view;
		this.containerId = options.containerId;
		this.optionClassName = options.optionClassName;
		this.optionActiveClassName = options.optionActiveClassName;
		this.onSelect = options.onSelect;

		this.container = document.createElement("div");
		this.container.id = options.containerId;
		this.container.className = options.containerClassName;
		this.container.setAttribute("role", "listbox");

		const self = this;

		this.provider = new SlashProvider({
			content: this.container,
			root: options.root,
			debounce: options.debounceMs,
			shouldShow(view: EditorView, prevState?: EditorState) {
				if (options.allow && !options.allow(view)) {
					self.closeMenu();
					return false;
				}

				const currentText = this.getContent(view) as string | null;
				if (!currentText) {
					self.closeMenu();
					return false;
				}

				const query = options.getQuery(currentText);
				if (query == null) {
					self.closeMenu();
					return false;
				}

				const items = options.getItems(query);
				if (items.length === 0) {
					self.closeMenu();
					return false;
				}

				self.openMenu(items, query);
				return true;
			},
		});

		this.keydownHandler = (e) => this.onKeyDown(e);
		this.view.dom.addEventListener("keydown", this.keydownHandler, true);

		this.update(view);
	}

	update(view: EditorView, prevState?: EditorState) {
		this.view = view;
		this.provider.update(view, prevState);
	}

	destroy() {
		this.view.dom.removeEventListener("keydown", this.keydownHandler, true);
		this.provider.destroy();
		this.closeMenu();
		this.container.remove();
	}

	private openMenu(items: TItem[], query: string) {
		const queryChanged = query !== this.currentQuery;

		this.isOpen = true;
		this.items = items;
		this.currentQuery = query;
		if (queryChanged) this.activeIndex = 0;

		const dom = this.view.dom as HTMLElement;
		dom.setAttribute("role", "combobox");
		dom.setAttribute("aria-expanded", "true");
		dom.setAttribute("aria-owns", this.containerId);

		this.renderOptions();
		this.updateActiveVisual();
	}

	private closeMenu() {
		if (!this.isOpen) return;

		this.isOpen = false;
		this.items = [];
		this.currentQuery = "";
		this.activeIndex = 0;

		const dom = this.view.dom as HTMLElement;
		dom.setAttribute("aria-expanded", "false");
		dom.removeAttribute("aria-activedescendant");
	}

	private renderOptions() {
		this.container.innerHTML = "";

		this.items.forEach((item, index) => {
			const element = document.createElement("div");
			element.textContent = item.label;
			element.className = this.optionClassName;
			element.setAttribute("role", "option");
			element.setAttribute("data-index", String(index));
			element.setAttribute("data-item-id", item.id);
			element.id = `${this.containerId}-option-${index}`;

			element.addEventListener("mousedown", (e) => {
				e.preventDefault();
				e.stopPropagation();
				this.selectIndex(index);
			});

			this.container.appendChild(element);
		});
	}

	private updateActiveVisual() {
		if (!this.isOpen) return;

		const options = Array.from(
			this.container.querySelectorAll<HTMLElement>("[role='option']"),
		);

		let activeId: string | null = null;

		options.forEach((el, idx) => {
			const isActive = idx === this.activeIndex;
			if (isActive) {
				activeId = el.id;
				el.className = `${this.optionClassName} ${this.optionActiveClassName}`;
				el.setAttribute("aria-selected", "true");
			} else {
				el.className = this.optionClassName;
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

	private onKeyDown(e: KeyboardEvent) {
		if (!this.isOpen) return;
		if (this.items.length === 0) return;

		const key = e.key;

		const isNext =
			key === "ArrowDown" || (e.ctrlKey && (key === "j" || key === "J"));

		const isPrev =
			key === "ArrowUp" || (e.ctrlKey && (key === "k" || key === "K"));

		if (isNext) {
			e.preventDefault();
			e.stopPropagation();
			this.activeIndex = (this.activeIndex + 1) % this.items.length;
			this.updateActiveVisual();
			return;
		}

		if (isPrev) {
			e.preventDefault();
			e.stopPropagation();
			this.activeIndex =
				(this.activeIndex - 1 + this.items.length) % this.items.length;
			this.updateActiveVisual();
			return;
		}

		switch (key) {
			case "Enter":
			case "Tab":
				e.preventDefault();
				e.stopPropagation();
				this.selectIndex(this.activeIndex);
				break;

			case "Escape":
				e.preventDefault();
				e.stopPropagation();
				this.provider.hide();
				this.closeMenu();
				break;
		}
	}

	private selectIndex(index: number) {
		const item = this.items[index];
		if (!item) return;

		const query = this.currentQuery;
		const view = this.view;

		this.provider.hide();
		this.closeMenu();
		this.onSelect(item, { view, query });
	}
}
