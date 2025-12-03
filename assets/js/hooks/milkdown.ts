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

import { Doc } from "yjs";
import {
	collab,
	CollabService,
	collabServiceCtx,
} from "@milkdown/plugin-collab";
import { WebsocketProvider } from "y-websocket";
const slash = slashFactory("Commands");

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
		const isView = mode === "view";
		this.statusReady = false;
		this.statusDot = this.el.dataset.statusDotId
			? document.getElementById(this.el.dataset.statusDotId)
			: null;
		this.statusLabel = this.el.dataset.statusLabelId
			? document.getElementById(this.el.dataset.statusLabelId)
			: null;
		this.lastSavedContent = this.normalize(markdown);
		this.currentContent = this.lastSavedContent;
		this.statusTimer = null;

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

		// Identify the page for the collaboration room (prefer stable DB id)
		const pageId = this.el.dataset.pageId;

		// Create Y.js document and WebSocket provider for collaboration
		this.yDoc = new Doc();
		this.wsProvider = null;
		this.collabService = null;
		this.handleDocUpdate = () => {
			if (!this.statusReady) return;
			this.scheduleStatusRefresh();
		};

		Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, this.el);

				if (isStatic) {
					ctx.set(defaultValueCtx, markdown);
				}

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
				this.editorInstance = editor;
				this.collabService = editor.ctx.get(collabServiceCtx);
				if (isStatic) {
					this.setEditable(false);
					this.statusReady = true;
					this.refreshStatus(true);
				} else {
					const allowEdit = isEdit && editable;
					this.setupCollaboration(pageId, markdown, allowEdit);
				}
				this.setupFormSync();

				this.yDoc.on("update", this.handleDocUpdate);
				this.handleEvent("collab_saved_version", ({ markdown }) => {
					this.lastSavedContent = this.normalize(markdown);
					if (this.statusReady) {
						this.refreshStatus(true);
					}
				});
			});
	},

	setupCollaboration(pageId, seedMarkdown, editable) {
		if (!pageId) {
			console.error("Milkdown collaboration requires pageId for room naming");
			return;
		}

		// Create WebSocket connection to collaboration server
		const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
		const wsUrl = `${protocol}//${window.location.host}/collab`;
		const roomName = `page-${pageId}`;

		this.wsProvider = new WebsocketProvider(wsUrl, roomName, this.yDoc);

		// Set up collaboration service
		this.collabService
			.bindDoc(this.yDoc)
			.setAwareness(this.wsProvider.awareness);

		// Wait for initial sync, then handle seeding
		this.wsProvider.once("synced", (isSynced) => {
			if (isSynced) {
				// Deterministic seeding using UUID protocol
				const metaMap = this.yDoc.getMap("meta");
				const seededVersion = metaMap.get("seeded_version_uuid");

				if (!seededVersion) {
					// First client to connect - seed the document
					const myUUID = crypto.randomUUID();
					metaMap.set("seeded_version_uuid", myUUID);

					// Apply template if we have seed markdown
					if (seedMarkdown && seedMarkdown.trim()) {
						this.collabService.applyTemplate(seedMarkdown);
					}
				}

				// Connect to collaboration and set editable state
				this.collabService.connect();
				this.setEditable(editable);

				if (editable) {
					this.setFocusAndCursorPos();
				}

				this.statusReady = true;
				// Align saved/current to the synced doc to avoid initial flicker
				const syncedContent = this.normalize(this.editorInstance.action(getMarkdown()));
				this.lastSavedContent = syncedContent;
				this.currentContent = syncedContent;
				this.refreshStatus(true);
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
			return false; // Stop after first node (ProseMirror forEach convention)
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
				// Extract current markdown from collaborative state for saving
				const currentMarkdown = this.editorInstance.action(getMarkdown());
				this.hiddenInput.value = currentMarkdown;
				this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
			};
			this.form.addEventListener("submit", this.handleSubmit);
		}
	},

	scheduleStatusRefresh() {
		if (this.statusTimer || !this.statusReady) {
			return;
		}

		this.statusTimer = window.setTimeout(() => {
			this.statusTimer = null;
			this.refreshStatus();
		}, 200);
	},

	refreshStatus(force = false) {
		if (!this.editorInstance) return;
		const nextContent = this.normalize(this.editorInstance.action(getMarkdown()));
		this.currentContent = nextContent;

		if (!force && this.currentContent === this.lastSavedContent) {
			// no change
		}

		const dirty = this.currentContent !== this.lastSavedContent;
		this.setStatusIndicator(dirty);
	},

	setStatusIndicator(dirty: boolean) {
		if (!this.statusDot || !this.statusLabel) return;

		this.statusDot.classList.toggle("bg-emerald-500", !dirty);
		this.statusDot.classList.toggle("bg-rose-500", dirty);
		this.statusLabel.textContent = dirty ? "Unsaved changes" : "Synced";
	},

	updated() {
		if (!this.editorInstance) return;

		// Update editable state (for switching between view/edit modes)
		this.setEditable(this.el.dataset.editable !== undefined);

		// Note: We don't update markdown content here since Y.js manages the collaborative state
		// The collaborative document is the single source of truth
	},

	destroyed() {
		// Clean up collaboration resources
		if (this.collabService) {
			this.collabService.disconnect();
			this.collabService = null;
		}

		if (this.wsProvider) {
			this.wsProvider.destroy();
			this.wsProvider = null;
		}

		if (this.yDoc) {
			if (this.handleDocUpdate) {
				this.yDoc.off("update", this.handleDocUpdate);
			}
			this.yDoc.destroy();
			this.yDoc = null;
		}

		// Clean up form event listeners
		this.form?.removeEventListener("submit", this.handleSubmit);
		this.editorInstance = null;
		this.form = null;
		this.hiddenInput = null;
		this.statusDot = null;
		this.statusLabel = null;
	},

	normalize(content: string | undefined | null) {
		return (content || "").trim();
	},
};

export default MilkdownEditor;
