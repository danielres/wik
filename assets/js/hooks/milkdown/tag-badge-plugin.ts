import type { PluginSpec } from "prosemirror-state";
import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

// Render #tags as linked badges (both editor + static).

type TagBadgeDecoState = { deco: DecorationSet };

// Normalize tag to bare, downcased name.
const TAG_REGEX = /(\s|^)(#([A-Za-z0-9_-]+))/g;

export function createTagBadgePlugin(tagRootPath: string) {
	const cleanTagRoot = tagRootPath.replace(/\/?$/, "");

	const spec: PluginSpec<TagBadgeDecoState> = {
		state: {
			init(_, { doc }) {
				return { deco: buildDecorations(doc, cleanTagRoot) };
			},
			apply(tr, prev) {
				if (!tr.docChanged) return prev;
				return { deco: buildDecorations(tr.doc, cleanTagRoot) };
			},
		},
		props: {
			decorations(state) {
				return this.getState(state)?.deco ?? null;
			},
		},
	};

	return new Plugin(spec);
}

function buildDecorations(doc: any, root: string) {
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

				let match: RegExpExecArray | null;

				while ((match = TAG_REGEX.exec(text))) {
					const full = match[2]; // includes '#'
					const name = match[3];
					if (!full || !name) continue;

					// Align to the '#' inside the match (skip leading whitespace/start).
					const startOfMatch = base + offset + match.index;
					const start = startOfMatch + (match[0].length - full.length);
					const end = start + full.length;
					const href = `${root}/${encodeURIComponent(name.toLowerCase())}`;

					decos.push(
						Decoration.inline(start, end, {
							nodeName: "a",
							class: "tag-badge",
							href,
							spellcheck: "false",
						}),
					);
				}
				TAG_REGEX.lastIndex = 0;
			}

			offset += child.nodeSize;
		});
		return false;
	});

	return DecorationSet.create(doc, decos);
}
