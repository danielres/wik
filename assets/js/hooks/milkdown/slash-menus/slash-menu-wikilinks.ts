import type { Ctx } from "@milkdown/ctx";
import { TextSelection } from "prosemirror-state";
import type { EditorView } from "prosemirror-view";

import { slashFactory } from "@milkdown/kit/plugin/slash";
import {
	createSlashMenuView,
	type SlashMenuItem,
} from "./components/slash-menu-view";
import { isSelectionInHeading } from "../utils/selection";

export type SlashMenuWikilinksPage = {
	id: string;
	label: string;
	slug: string;
	updatedAtMs: number | null;
};

export const slashMenuWikilinks = slashFactory("SLASH_MENU_WIKILINKS");

type PageItem = SlashMenuItem & { slug: string };

export function slashMenuWikilinksRegister(
	ctx: Ctx,
	pages: SlashMenuWikilinksPage[],
	rootPath: string,
) {
	if (!Array.isArray(pages)) throw new TypeError("pages must be an array");
	if (typeof rootPath !== "string")
		throw new TypeError("rootPath must be a string");

	const allPages = pages.slice();

	ctx.set(slashMenuWikilinks.key, {
		view: createSlashMenuView<PageItem>({
			containerId: "slash-menu-wikilinks",
			containerClassName: "slash-menu-wikilinks-container",
			optionClassName: "slash-menu-wikilinks-option",
			optionActiveClassName: "slash-menu-wikilinks-option-active",
			debounceMs: 0,
			allow: (view) => !isSelectionInHeading(view),
			getQuery: (textBlockContent) => {
				const match = textBlockContent.match(/\[\[([^\]]*)$/);
				return match ? (match[1] ?? "") : null;
			},
			getItems: (query) => {
				const filtered = filterPages(allPages, query);
				return filtered.map((p) => ({
					id: p.id,
					label: p.label,
					slug: p.slug,
				}));
			},
			onSelect: (item, { view, query }) => {
				insertWikilink(view, {
					query,
					label: item.label,
					id: item.id,
				});
			},
		}),
	});
}

/* ---------------- FILTERING ---------------- */

const RECENT_LIMIT = 5;

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

function filterPages(
	pages: SlashMenuWikilinksPage[],
	query: string,
): SlashMenuWikilinksPage[] {
	const q = query.trim();

	if (q === "") {
		return pages
			.slice()
			.sort((a, b) => (b.updatedAtMs ?? 0) - (a.updatedAtMs ?? 0))
			.slice(0, RECENT_LIMIT);
	}

	return pages
		.map((p) => ({
			page: p,
			score: fuzzyScore(p.label, q) || fuzzyScore(p.slug, q),
		}))
		.filter((x) => x.score > 0)
		.sort((a, b) => b.score - a.score)
		.map((x) => x.page)
		.slice(0, 20);
}

/* ---------------- INSERT ---------------- */

function insertWikilink(
	view: EditorView,
	opts: { query: string; label: string; id: string },
) {
	const { state } = view;
	const { from } = state.selection;

	const deleteLen = opts.query.length + 2; // "[[" + query
	const start = Math.max(0, from - deleteLen);

	const { schema } = state;
	const wikilinkType = schema.nodes["wikilink"];
	if (!wikilinkType) {
		console.error("Wikilink node not found in schema");
		return;
	}

	const linkNode = wikilinkType.create({ id: opts.id, label: opts.label });

	const tr = state.tr.replaceWith(start, from, linkNode);
	const posAfter = start + linkNode.nodeSize;
	tr.setSelection(TextSelection.create(tr.doc, posAfter));
	tr.setStoredMarks([]);

	view.dispatch(tr);
}
