import { CommandManager, commandsCtx } from "@milkdown/core";
import type { SliceType } from "@milkdown/ctx";
import { selectTextNearPosCommand } from "@milkdown/kit/preset/commonmark";
import { Doc } from "yjs";
import { undo } from "y-prosemirror";
import { initCollab, type CollabHandles } from "./milkdown/collab";
import {
	createMilkdownEditor,
	editorViewCtx,
	getMarkdown,
} from "./milkdown/setup";
import type { SlashMenuWikilinksPage } from "./milkdown/slash-menu-wikilinks";
import { StatusIndicator } from "./milkdown/status";

function normalize(content: string | undefined | null) {
	return (content || "").trim();
}

const MilkdownEditor = {
	mounted() {
		const {
			markdown = "",
			editable: _editable,
			inputId,
			rootPath = "",
			mode = "view",
		} = this.el.dataset;

		const pagesJson = this.el.dataset.pagesJson;
		const editable = _editable !== undefined;
		const isStatic = mode === "static";
		const isEdit = mode === "edit";

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

		const pageId = this.el.dataset.pageId;
		this.yDoc = new Doc();
		this.collabHandles = null as CollabHandles | null;
		this.editorInstance = null;
		this.handleDocUpdate = null;
		this.doneLink = null;
		this.doneHandler = null;
		this.awareness = null;

		const statusTargetEl = document.querySelector("main") as HTMLElement | null;
		this.status = new StatusIndicator(
			this.el.dataset.statusDotId
				? document.getElementById(this.el.dataset.statusDotId)
				: null,
			this.el.dataset.statusLabelId
				? document.getElementById(this.el.dataset.statusLabelId)
				: null,
			normalize(markdown),
			statusTargetEl,
		);
		this.userMeta = this.el.dataset.userMeta
			? JSON.parse(this.el.dataset.userMeta)
			: {};
		this.doneLink = document.querySelector("[data-done-target]") as
			| HTMLAnchorElement
			| HTMLButtonElement
			| null;

		createMilkdownEditor({
			root: this.el as HTMLElement,
			markdown,
			pages,
			rootPath,
			isStatic,
		}).then(({ editor, collabService }) => {
			this.editorInstance = editor;
			this.collabService = collabService;

			const fetchCurrent = () =>
				normalize(this.editorInstance.action(getMarkdown()));

			if (isStatic) {
				this.setEditable(false);
				const content = fetchCurrent();
				this.status.updateCurrent(content);
				this.status.setReady();
			} else {
				const allowEdit = isEdit && editable;
				this.collabHandles = initCollab({
					pageId,
					seedMarkdown: markdown,
					editable: allowEdit,
					yDoc: this.yDoc,
					collabService: this.collabService,
					onReady: () => {
						this.setEditable(allowEdit);
						if (allowEdit) this.setFocusAndCursorPos();
						const syncedContent = fetchCurrent();
						this.status.updateCurrent(syncedContent);
						this.status.setReady();
						this.applyAwarenessMeta();
					},
				});
				this.awareness = this.collabHandles?.awareness;
			}

			this.setupFormSync();

			this.handleDocUpdate = () => {
				this.status.scheduleRefresh(fetchCurrent);
			};
			this.yDoc.on("update", this.handleDocUpdate);

			this.handleEvent("collab_saved_version", ({ markdown }) => {
				this.status.markSaved(normalize(markdown));
				this.status.scheduleRefresh(fetchCurrent);
			});

			if (this.doneLink) {
				this.doneHandler = (event: Event) => {
					event.preventDefault();
					this.undoUntilSaved(fetchCurrent).finally(() => {
						if (this.doneLink instanceof HTMLAnchorElement) {
							window.location.href = this.doneLink.href;
						}
					});
				};
				this.doneLink.addEventListener("click", this.doneHandler);
			}
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
				const currentMarkdown = this.editorInstance.action(getMarkdown());
				this.hiddenInput.value = currentMarkdown;
				this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
			};
			this.form.addEventListener("submit", this.handleSubmit);
		}
	},

	updated() {
		if (!this.editorInstance) return;
		this.setEditable(this.el.dataset.editable !== undefined);
		// Re-apply status to restore data attributes after LiveView patches
		if (this.status) {
			this.status.refresh();
		}
	},

	destroyed() {
		if (this.collabService) {
			this.collabService.disconnect();
			this.collabService = null;
		}

		if (this.collabHandles) {
			this.collabHandles.destroy();
			this.collabHandles = null;
		}

		if (this.yDoc) {
			if (this.handleDocUpdate) {
				this.yDoc.off("update", this.handleDocUpdate);
			}
			this.yDoc.destroy();
			this.yDoc = null;
		}

		this.form?.removeEventListener("submit", this.handleSubmit);
		this.editorInstance = null;
		this.form = null;
		this.hiddenInput = null;
		this.status = null;
		if (this.doneLink && this.doneHandler) {
			this.doneLink.removeEventListener("click", this.doneHandler);
		}
		this.doneLink = null;
		this.doneHandler = null;
		this.userMeta = null;
		this.awareness = null;
	},

	applyAwarenessMeta() {
		if (!this.awareness || !this.userMeta) return;
		this.awareness.setLocalStateField("user", this.userMeta);
	},

	async undoUntilSaved(fetchCurrent: () => string) {
		const target = this.status ? this.status.getLastSaved() : null;
		if (!target) return;

		const view = this.editorInstance?.ctx.get(editorViewCtx);
		if (!view) return;

		const maxSteps = 1000;
		let steps = 0;

		while (steps < maxSteps) {
			const current = fetchCurrent();
			if (current === target) break;
			const didUndo = undo(view.state, view.dispatch);
			if (!didUndo) break;
			steps += 1;
			await new Promise((resolve) => requestAnimationFrame(resolve));
		}
	},
};

export default MilkdownEditor;
