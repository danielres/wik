import { CommandManager, commandsCtx } from "@milkdown/core";
import type { SliceType } from "@milkdown/ctx";
import { selectTextNearPosCommand } from "@milkdown/kit/preset/commonmark";
import { Doc } from "yjs";
import { redo, undo } from "prosemirror-history";
import { initCollab, type CollabHandles } from "./milkdown/collab";
import {
	createMilkdownEditor,
	editorViewCtx,
	getMarkdown,
} from "./milkdown/setup";
import type { SlashMenuWikilinksPage } from "./milkdown/slash-menu-wikilinks";
import { StatusIndicator } from "./milkdown/status";
import { readUndoRedoState } from "./milkdown/undo-state";

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
		const editable = _editable === "true";
		const isStatic = mode === "static";
		const isEdit = mode === "edit";
		this.mode = mode;

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
		this.undoBtn = null;
		this.redoBtn = null;
		this.undoHandler = null;
		this.redoHandler = null;
		this.awareness = null;
		this.statePushTimer = null;
		this.statePending = null;
		this.stateLastSent = null;
		this.docUpdatesAttached = false;

		this.status = new StatusIndicator(normalize(markdown));
		this.userMeta = this.el.dataset.userMeta
			? JSON.parse(this.el.dataset.userMeta)
			: {};
		this.undoBtn = this.el.dataset.undoId
			? (document.getElementById(
					this.el.dataset.undoId,
				) as HTMLButtonElement | null)
			: null;
		this.redoBtn = this.el.dataset.redoId
			? (document.getElementById(
					this.el.dataset.redoId,
				) as HTMLButtonElement | null)
			: null;

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
			this.fetchCurrent = fetchCurrent;

			if (isStatic) {
				this.setEditable(false);
				const content = fetchCurrent();
				this.status.updateCurrent(content);
				this.status.setReady();
				this.maybePushEditorState(true);
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
						this.maybePushEditorState(true);
					},
				});
				this.awareness = this.collabHandles?.awareness;
				this.applyAwarenessMeta();
			}

			this.setupFormSync();

			if (isEdit) {
				this.attachDocUpdates(fetchCurrent);
			}

			this.handleEvent("collab_saved_version", ({ markdown }) => {
				this.status.markSaved(normalize(markdown));
				this.status.updateCurrent(fetchCurrent());
				if (this.mode === "edit") this.maybePushEditorState(true);
			});

			this.handleEvent("submit_page_form", ({ form_id }) => {
				const form = form_id
					? (document.getElementById(form_id) as HTMLFormElement | null)
					: null;
				form?.requestSubmit();
			});

			this.handleEvent("revert_to_saved", () => {
				this.undoUntilSaved(fetchCurrent).finally(() => {
					this.pushEvent("revert_done", { ok: true });
				});
			});

			this.handleEvent("set_editable", ({ editable }) => {
				this.el.dataset.editable = editable ? "true" : "";
				this.mode = editable ? "edit" : "view";
				this.el.dataset.mode = this.mode;
				if (this.editorInstance) {
					this.setEditable(!!editable);
					if (this.mode === "edit") {
						this.attachDocUpdates(this.fetchCurrent);
						this.maybePushEditorState(true);
					}
				}
			});


			this.attachUndoRedo();
			if (this.mode === "edit") this.maybePushEditorState(true);
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
		view.setProps({
			editable: () => editable,
		});
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
		this.setEditable(this.el.dataset.editable === "true");
		// Re-attach status targets in case LiveView patched them
		if (this.status) this.status.refresh();

		// Rebind undo/redo buttons if LiveView replaced them
		this.undoBtn = this.el.dataset.undoId
			? (document.getElementById(
					this.el.dataset.undoId,
				) as HTMLButtonElement | null)
			: null;
		this.redoBtn = this.el.dataset.redoId
			? (document.getElementById(
					this.el.dataset.redoId,
				) as HTMLButtonElement | null)
			: null;
		this.attachUndoRedo();
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
		if (this.undoBtn && this.undoHandler) {
			this.undoBtn.removeEventListener("click", this.undoHandler);
		}
		if (this.redoBtn && this.redoHandler) {
			this.redoBtn.removeEventListener("click", this.redoHandler);
		}
		this.undoBtn = null;
		this.redoBtn = null;
		this.undoHandler = null;
		this.redoHandler = null;
		this.userMeta = null;
		this.awareness = null;
		if (this.statePushTimer) window.clearTimeout(this.statePushTimer);
		this.statePushTimer = null;
		this.statePending = null;
		this.stateLastSent = null;
	},

	applyAwarenessMeta() {
		if (!this.awareness || !this.userMeta) return;
		const withColor = {
			...this.userMeta,
			...pastelForName(this.userMeta.name || ""),
		};
		this.awareness.setLocalStateField("user", withColor);
	},

	async undoUntilSaved(fetchCurrent: () => string) {
		const target = this.status ? this.status.getLastSaved() : null;
		if (target == null) return;

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

	attachUndoRedo() {
		const view = this.editorInstance?.ctx.get(editorViewCtx);
		const editable = this.el.dataset.editable === "true";

		// Always detach existing handlers first (mode toggles / LV patches).
		if (this.undoBtn && this.undoHandler)
			this.undoBtn.removeEventListener("click", this.undoHandler);
		if (this.redoBtn && this.redoHandler)
			this.redoBtn.removeEventListener("click", this.redoHandler);
		this.undoHandler = null;
		this.redoHandler = null;

		if (!view || !editable) return;

		if (this.undoBtn) {
			this.undoHandler = (event: Event) => {
				event.preventDefault();
				undo(view.state, view.dispatch);
				this.maybePushEditorState();
			};
			this.undoBtn.addEventListener("click", this.undoHandler);
		}

		if (this.redoBtn) {
			this.redoHandler = (event: Event) => {
				event.preventDefault();
				redo(view.state, view.dispatch);
				this.maybePushEditorState();
			};
			this.redoBtn.addEventListener("click", this.redoHandler);
		}
	},

	maybePushEditorState(force = false) {
		// Only report state when in edit mode
		if (this.mode !== "edit") return;

		const view = this.editorInstance?.ctx.get(editorViewCtx);
		const { hasUndo, hasRedo } = readUndoRedoState(view ?? null);
		const synced = this.status ? this.status.isSynced() : true;

		const payload = {
			"synced?": synced,
			"has_undo?": hasUndo,
			"has_redo?": hasRedo,
		};

		const same =
			this.stateLastSent &&
			this.stateLastSent["synced?"] === payload["synced?"] &&
			this.stateLastSent["has_undo?"] === payload["has_undo?"] &&
			this.stateLastSent["has_redo?"] === payload["has_redo?"];

		if (same && !force) return;

		if (this.statePushTimer && !force) {
			this.statePending = payload;
			return;
		}

		const push = (data: typeof payload) => {
			this.pushEvent("editor_state", data);
			this.stateLastSent = data;
		};

		if (force) {
			if (this.statePushTimer) window.clearTimeout(this.statePushTimer);
			this.statePushTimer = null;
			this.statePending = null;
			push(payload);
			return;
		}

		this.statePending = payload;
		this.statePushTimer = window.setTimeout(() => {
			if (this.statePending) push(this.statePending);
			this.statePending = null;
			this.statePushTimer = null;
		}, 150);
	},

	attachDocUpdates(fetchCurrent: () => any) {
		if (this.docUpdatesAttached) return;
		this.handleDocUpdate = () => {
			this.status.updateCurrent(fetchCurrent());
			this.maybePushEditorState();
		};
		this.yDoc.on("update", this.handleDocUpdate);
		this.docUpdatesAttached = true;
	},
};

export default MilkdownEditor;

function pastelForName(name: string) {
	let hash = 0;
	for (let i = 0; i < name.length; i++) {
		hash = name.charCodeAt(i) + ((hash << 5) - hash);
		hash |= 0;
	}

	const hue = Math.abs(hash) % 360;
	const color = `hsl(${hue}, 60%, 55%)`;

	return { color };
}
