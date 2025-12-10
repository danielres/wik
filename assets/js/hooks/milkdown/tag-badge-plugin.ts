import type { PluginSpec } from "prosemirror-state";
import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

// Render #tags as linked badges (both editor + static).

type TagBadgeDecoState = { deco: DecorationSet };

// Normalize tag to bare, downcased name.
// Matches a leading boundary (start or non-word-ish) + #tag, allowing letters (ASCII + extended Latin),
// combining marks, digits, _, -, and / — without relying on Unicode property escapes (keeps esbuild targets happy).
const TAG_REGEX =
	/(^|[^\w-])(#([\w\u00C0-\u02FF\u1E00-\u1EFF\u0300-\u036F/-]+))/g;

export function createTagBadgePlugin(tagRootPath: string) {
	const cleanTagRoot = tagRootPath.replace(/\/?$/, "");

	const state = createTagBadgeState();

	// DOM event wiring
	const spec: PluginSpec<TagBadgeDecoState> = {
		state: {
			init(_, { doc }) {
				return {
					deco: buildDecorations(doc, cleanTagRoot, state.typingPos),
				};
			},
			apply(tr, prev) {
				if (!tr.docChanged && !tr.getMeta("force-decoration-update"))
					return prev;

				// Update typing position only when not composing or committing
				const selection = tr.selection;
				if (
					selection &&
					selection.empty &&
					!state.isComposing &&
					!state.pendingCommit
				) {
					const hasTextChanges = tr.steps.some(
						(step: any) =>
							step.stepType?.name === "replace" ||
							step.stepType?.name === "replaceAround",
					);

					if (hasTextChanges) {
						state.setTyping(selection.head);
					}
				}

				return {
					deco: buildDecorations(tr.doc, cleanTagRoot, state.typingPos),
				};
			},
		},
		props: {
			decorations(state) {
				return this.getState(state)?.deco ?? null;
			},
			handleDOMEvents: {
				keydown(view, event) {
					if (
						event.key === " " ||
						event.key === "Enter" ||
						event.key === "Tab"
					) {
						state.pendingCommit = true;
						state.isComposing = false;
						state.clearComposeTimer();
						state.clearTyping();
						state.requestRefresh(view);
					} else if (event.key === "Dead") {
						state.startComposition(view);
					} else {
						// Any other key ends composition-like state
						state.isComposing = false;
						state.clearComposeTimer();
					}
					return false;
				},
				input(view, event) {
					if (event.inputType === "insertCompositionText") {
						state.startComposition(view);
					} else {
						state.isComposing = false;
						state.clearComposeTimer();
					}

					if (state.pendingCommit) {
						return false;
					}

					if (
						event.inputType?.startsWith("insert") ||
						event.inputType?.startsWith("delete")
					) {
						const selection = view.state.selection;
						if (selection && selection.empty) {
							state.setTyping(selection.head);
						}
					}
					return false;
				},
				compositionstart() {
					state.isComposing = true;
					state.clearComposeTimer();
					return false;
				},
				compositionend(view) {
					state.endComposition(view, true);
					return false;
				},
			},
			destroy() {
				state.destroy?.();
			},
		},
	};

	return new Plugin(spec);
}

function buildDecorations(doc: any, root: string, typingPosition: number) {
	const decos: Decoration[] = [];

	doc.descendants((node: any, pos: number) => {
		// Skip code blocks / code marks contexts.
		if (node.type?.spec?.code) return false;

		const base = pos + 1; // children start at pos+1 within this node
		let offset = 0;

		node.forEach((child: any) => {
			if (child.isText && child.text) {
				// Skip if the text already has a code or link mark.
				if (
					child.marks?.some(
						(m: any) => m.type?.spec?.code || m.type?.name === "link",
					)
				) {
					offset += child.nodeSize;
					return;
				}

				const text = child.text as string;
				const tags = findTagsWithCorrectPositions(text);

				for (const tag of tags) {
					const start = base + offset + tag.start;
					const end = base + offset + tag.end;

					if (isWithinTag(typingPosition, start, end)) {
						continue;
					}

					const href = `${root}/${encodeURIComponent(tag.name.toLowerCase())}`;

					decos.push(
						Decoration.inline(start, end, {
							nodeName: "a",
							class: "tag-badge",
							href,
							spellcheck: "false",
						}),
					);
				}
			}

			offset += child.nodeSize;
		});
		return false;
	});

	return DecorationSet.create(doc, decos);
}

/**
 * Find tags in text with Unicode-safe position calculation.
 * This avoids the UTF-16/Unicode code point mismatch issue that occurs
 * when emojis or other multi-byte characters precede tags in the text.
 */
function findTagsWithCorrectPositions(text: string): Array<{
	start: number;
	end: number;
	name: string;
	full: string;
}> {
	const results: Array<{
		start: number;
		end: number;
		name: string;
		full: string;
	}> = [];

	TAG_REGEX.lastIndex = 0;

	let match: RegExpExecArray | null;

	while ((match = TAG_REGEX.exec(text))) {
		const full = match[2]; // includes '#'
		const name = match[3];
		if (!full || !name) continue;

		// Calculate the start position of the '#' symbol
		// Skip the leading boundary character (match[1])
		const matchStart = match.index;
		const boundaryLength = match[1].length;
		const tagStart = matchStart + boundaryLength;

		// Convert UTF-16 indices to Unicode code point positions
		// by counting actual characters up to that point
		const unicodeStart = getUnicodePosition(text, tagStart);
		const unicodeEnd = unicodeStart + Array.from(full).length;

		results.push({
			start: unicodeStart,
			end: unicodeEnd,
			name,
			full,
		});
	}

	TAG_REGEX.lastIndex = 0;
	return results;
}

/**
 * Convert a UTF-16 byte index to a Unicode code point position.
 * This handles multi-byte characters like emojis and surrogate pairs properly.
 */
function getUnicodePosition(text: string, utf16Index: number): number {
	// Get the substring up to the UTF-16 index
	const substring = text.substring(0, utf16Index);
	// Count actual Unicode characters (code points)
	return Array.from(substring).length;
}

function isWithinTag(cursor: number, start: number, end: number) {
	return cursor >= start && cursor <= end;
}

function createTagBadgeState() {
	const COMPOSE_FALLBACK_MS = 30;
	let refreshTimer: ReturnType<typeof setTimeout> | null = null;
	let composeTimer: ReturnType<typeof setTimeout> | null = null;

	let typingPos = -1;
	let pendingCommit = false;
	let isComposing = false;

	const clearTyping = () => {
		typingPos = -1;
	};

	const setTyping = (pos: number | null) => {
		typingPos = pos ?? -1;
	};

	const clearComposeTimer = () => {
		if (composeTimer) {
			clearTimeout(composeTimer);
			composeTimer = null;
		}
	};

	const endComposition = (view: any, forceRebuild = false) => {
		isComposing = false;
		pendingCommit = false;
		clearComposeTimer();
		clearTyping();
		if (forceRebuild) {
			requestRefresh(view);
		}
	};

	const dispatchRefresh = (view: any) => {
		refreshTimer = null;
		if (view.isDestroyed) return;
		const tr = view.state.tr.setMeta("force-decoration-update", Date.now());
		view.dispatch(tr);
		pendingCommit = false;
	};

	const requestRefresh = (view: any) => {
		if (refreshTimer) return;
		refreshTimer = setTimeout(() => dispatchRefresh(view), 0);
	};

	const startComposition = (view: any, delay = COMPOSE_FALLBACK_MS) => {
		isComposing = true;
		clearComposeTimer();
		composeTimer = setTimeout(() => {
			isComposing = false;
			pendingCommit = false;
			clearTyping();
			requestRefresh(view);
		}, delay);
	};

	return {
		get typingPos() {
			return typingPos;
		},
		set typingPos(v: number) {
			typingPos = v;
		},
		get pendingCommit() {
			return pendingCommit;
		},
		set pendingCommit(v: boolean) {
			pendingCommit = v;
		},
		get isComposing() {
			return isComposing;
		},
		set isComposing(v: boolean) {
			isComposing = v;
		},
		destroy() {
			if (refreshTimer) clearTimeout(refreshTimer);
			if (composeTimer) clearTimeout(composeTimer);
			refreshTimer = null;
			composeTimer = null;
		},
		clearTyping,
		setTyping,
		clearComposeTimer,
		startComposition,
		endComposition,
		requestRefresh,
	};
}
