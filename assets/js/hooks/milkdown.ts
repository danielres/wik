import { CommandManager, commandsCtx } from "@milkdown/core";
import type { SliceType } from "@milkdown/ctx";
import { selectTextNearPosCommand } from "@milkdown/kit/preset/commonmark";
import { Doc } from "yjs";
import { redo, undo } from "prosemirror-history";
import { initCollab, type CollabHandles } from "./milkdown/collab";
import { markdownValidator } from "./milkdown/markdown-validator";
import {
	createMilkdownEditor,
	editorViewCtx,
	getMarkdown,
} from "./milkdown/setup";
import type { SlashMenuWikilinksPage } from "./milkdown/slash-menus/slash-menu-wikilinks";

import { StatusIndicator } from "./milkdown/status";
import { readUndoRedoState } from "./milkdown/undo-state";

function normalize(content: string | undefined | null) {
	return (content || "").trim();
}

function extractPlainTitleFromEditorView(view: any) {
	// We derive the title from ProseMirror's document (not markdown) because `textContent`
	// already excludes formatting markers like `**bold**`, `*italic*`, `[link](url)`, etc.
	// We only apply our domain-specific normalization (strip `#tags`, collapse whitespace).
	const first = view?.state?.doc?.firstChild;
	if (!first) return null;
	if (first.type?.name !== "heading") return null;
	if (first.attrs?.level !== 1) return null;

	let title = (first.textContent || "").trim();
	if (title === "") return null;

	// Strip tags like #tag or #tag/subtag
	title = title.replace(/(^|\s)#[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*/g, " ");
	title = title.replace(/\s+/g, " ").trim();

	return title === "" ? null : title;
}

const EDITOR_STATE_PUSH_DEBOUNCE_MS = 150;

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

		this.pagesById = new Map();

		if (pagesJson) {
			try {
				const parsed = JSON.parse(pagesJson) as Record<
					string,
					{ id: string; slug: string; title?: string; updated_at?: string }
				>;

				pages = Object.values(parsed).map((p, i) => {
					const id = String(p.id ?? i);
					const slug = String(p.slug ?? "");
					const title = String(p.title ?? "");

					this.pagesById.set(id, { id, slug, title });

					return {
						id,
						label: title || slug || "",
						slug,
						updatedAtMs: p.updated_at ? Date.parse(p.updated_at) : null,
					};
				});
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
		this.markdownValidator = null;

		this.el.dataset.pageTitle = normalize(this.el.dataset.pageTitle) || "";

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
			wikilinks: {
				getPageById: (id: string) => this.pagesById.get(id) ?? null,
				resolveRef: async (title: string) => {
					const reply = await this.resolveOrCreatePageByTitle(title);
					if (!reply?.ok || !reply.page) return null;
					this.pagesById.set(String(reply.page.id), {
						id: String(reply.page.id),
						slug: String(reply.page.slug),
						title: String(reply.page.title ?? ""),
					});
					return {
						id: String(reply.page.id),
						slug: String(reply.page.slug),
						title: String(reply.page.title ?? ""),
					};
				},
			},
		}).then(({ editor, collabService }) => {
			this.editorInstance = editor;
			this.collabService = collabService;

			const ensureMarkdownValidator = () => {
				if (this.markdownValidator) return;

				this.markdownValidator = markdownValidator({
					seedMarkdown: markdown,
					serialize: () => this.editorInstance.action(getMarkdown()),
					normalize,
					onValidMarkdown: (current) => {
						this.status?.updateCurrent(current);
					},
					onAfterRefresh: (_result, { immediate }) => {
						this.maybePushEditorState(immediate);
					},
					onError: (e) => {
						console.error("Failed to serialize markdown", e);
					},
				});
			};

			if (isStatic) {
				this.setEditable(false);
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
						if (allowEdit) {
							ensureMarkdownValidator();
							this.markdownValidator?.refresh({ immediate: true });
						}
						this.status.setReady();
						this.applyAwarenessMeta();
					},
				});
				this.awareness = this.collabHandles?.awareness;
				this.applyAwarenessMeta();
			}

			this.setupFormSync();

			if (isEdit) {
				this.attachDocUpdates();
			}

			this.handleEvent("collab_saved_version", ({ markdown }) => {
				this.status.markSaved(normalize(markdown));
				const view = this.editorInstance?.ctx?.get?.(editorViewCtx);
				const title = extractPlainTitleFromEditorView(view);
				if (title) this.el.dataset.pageTitle = title;
				ensureMarkdownValidator();
				this.markdownValidator?.refresh({ immediate: true });
			});

			this.handleEvent("submit_page_form", ({ form_id }) => {
				const form = form_id
					? (document.getElementById(form_id) as HTMLFormElement | null)
					: null;
				form?.requestSubmit();
			});

			this.handleEvent("revert_to_saved", () => {
				this.undoUntilSaved()
					.then((reverted: boolean) => {
						this.pushEvent("revert_done", { ok: reverted !== false });
					})
					.catch(() => {
						this.pushEvent("revert_done", { ok: false });
					});
			});

			this.handleEvent("set_editable", ({ editable }) => {
				this.el.dataset.editable = editable ? "true" : "";
				this.mode = editable ? "edit" : "view";
				this.el.dataset.mode = this.mode;
				if (this.editorInstance) {
					this.setEditable(!!editable);
					if (this.mode === "edit") {
						ensureMarkdownValidator();
						this.attachDocUpdates();
						this.markdownValidator?.refresh({ immediate: true });
					} else {
						this.detachDocUpdates?.();
						this.markdownValidator?.destroy?.();
						this.markdownValidator = null;
					}
				}
			});

			this.attachUndoRedo();
			if (this.mode === "edit") {
				ensureMarkdownValidator();
				this.markdownValidator?.refresh({ immediate: true });
			}
		});
	},

	resolveOrCreatePageByTitle(title: string): Promise<{
		ok: boolean;
		page?: { id: string; slug: string; title: string };
		error?: string;
	}> {
		return new Promise((resolve) => {
			this.pushEvent("wikilink_create", { title }, (reply: any) => {
				resolve(reply);
			});
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
			this.handleSubmit = (event: Event) => {
				if (this.mode !== "edit") return;

				const result = this.markdownValidator?.refresh({ immediate: true });
				if (!result || !result.ok || result.markdown == null) {
					event.preventDefault();
					event.stopPropagation();
					this.maybePushEditorState(true);
					return;
				}

				const view = this.editorInstance?.ctx?.get?.(editorViewCtx);
				const title = extractPlainTitleFromEditorView(view);
				if (title) this.el.dataset.pageTitle = title;

				this.hiddenInput.value = result.markdown;
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
		this.markdownValidator?.destroy?.();
		this.markdownValidator = null;
	},

	applyAwarenessMeta() {
		if (!this.awareness || !this.userMeta) return;
		const withColor = {
			...this.userMeta,
			...pastelForName(this.userMeta.name || ""),
		};
		this.awareness.setLocalStateField("user", withColor);
	},

	async undoUntilSaved() {
		const target = this.status ? this.status.getLastSaved() : null;
		if (target == null) return false;

		if (!this.markdownValidator) return false;

		const view = this.editorInstance?.ctx.get(editorViewCtx);
		if (!view) return false;

		const maxSteps = 1000;
		let steps = 0;

		while (steps < maxSteps) {
			const current = this.markdownValidator.refresh();
			if (current.ok && current.markdown === target) return true;
			const didUndo = undo(view.state, view.dispatch);
			if (!didUndo) break;
			steps += 1;
			await new Promise((resolve) => requestAnimationFrame(resolve));
		}

		const final = this.markdownValidator.refresh();
		this.maybePushEditorState(true);

		return final.ok && final.markdown === target;
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
		const markdownOk = this.markdownValidator?.isValid?.() ?? true;
		const synced = markdownOk && this.status ? this.status.isSynced() : false;

		const payload = {
			"synced?": synced,
			"has_undo?": hasUndo,
			"has_redo?": hasRedo,
			"markdown_ok?": markdownOk,
		};

		const same =
			this.stateLastSent &&
			this.stateLastSent["synced?"] === payload["synced?"] &&
			this.stateLastSent["has_undo?"] === payload["has_undo?"] &&
			this.stateLastSent["has_redo?"] === payload["has_redo?"] &&
			this.stateLastSent["markdown_ok?"] === payload["markdown_ok?"];

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
		}, EDITOR_STATE_PUSH_DEBOUNCE_MS);
	},

	attachDocUpdates() {
		if (this.docUpdatesAttached) return;
		this.handleDocUpdate = () => {
			this.markdownValidator?.scheduleValidation();
		};
		this.yDoc.on("update", this.handleDocUpdate);
		this.docUpdatesAttached = true;
	},

	detachDocUpdates() {
		if (!this.docUpdatesAttached) return;
		if (this.yDoc && this.handleDocUpdate)
			this.yDoc.off("update", this.handleDocUpdate);
		this.docUpdatesAttached = false;
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
