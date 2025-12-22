import type { Ctx } from "@milkdown/ctx";
import type { Node as MarkdownNode } from "@milkdown/transformer";
import type { Node as ProseNode } from "@milkdown/prose/model";
import type { NodeViewConstructor } from "@milkdown/prose/view";

import { $ctx, $nodeSchema, $remark, $view } from "@milkdown/utils";
import { visit } from "unist-util-visit";

type PageInfo = { id: string; slug: string; title: string };

export type WikilinkConfig = {
	rootPath: string;
	getPageById: (id: string) => PageInfo | null;
};

const WIKIID_PREFIX = "wikid:";

function encodeSlugPath(slug: string) {
	return slug
		.split("/")
		.map((seg) => encodeURIComponent(seg))
		.join("/");
}

function getLabelFromMarkdown(node: MarkdownNode): string {
	const parts: string[] = [];
	visit(node, "text", (child: any) => {
		if (typeof child.value === "string") parts.push(child.value);
	});
	return parts.join("");
}

export const wikilinkConfig = $ctx<WikilinkConfig>(
	{
		rootPath: "",
		getPageById: () => null,
	},
	"wikilinkConfig",
);

export const remarkWikilinkPlugin = $remark(
	"remark-wikilink",
	() => () => (tree: MarkdownNode) => {
		visit(tree, "link", (node: any, index: number, parent: any) => {
			if (!parent || typeof index !== "number") return;
			const url = typeof node.url === "string" ? node.url : "";
			if (!url.startsWith(WIKIID_PREFIX)) return;

			const id = url.slice(WIKIID_PREFIX.length);
			if (!id) return;

			const label = getLabelFromMarkdown(node);

			const wikilink = {
				type: "wikilink",
				id,
				label,
			};

			parent.children.splice(index, 1, wikilink);
		});
	},
);

export const wikilinkSchema = $nodeSchema("wikilink", (ctx: Ctx) => ({
	inline: true,
	group: "inline",
	atom: true,
	selectable: true,
	marks: "",
	attrs: {
		id: { default: "" },
		label: { default: "" },
	},
	parseMarkdown: {
		match: (node) => node.type === "wikilink",
		runner: (state, node, type) => {
			const id = String((node as any).id ?? "");
			const label = String((node as any).label ?? "");
			state.addNode(type, { id, label });
		},
	},
	toMarkdown: {
		match: (node) => node.type.name === "wikilink",
		runner: (state, node) => {
			const id = String(node.attrs.id ?? "");
			const label = String(node.attrs.label ?? "");
			const url = `${WIKIID_PREFIX}${id}`;

			state.addNode("link", [{ type: "text", value: label }], undefined, {
				url,
				title: null,
			});
		},
	},
	parseDOM: [
		{
			tag: "a[data-wikilink-id]",
			priority: 100,
			getAttrs: (dom) => {
				if (!(dom instanceof HTMLElement)) return false;
				const id = dom.getAttribute("data-wikilink-id") || "";
				if (!id) return false;
				return {
					id,
					label: dom.textContent || "",
				};
			},
		},
	],
	toDOM: (node) => [
		"a",
		{
			class: "wikilink-node",
			"data-wikilink-id": node.attrs.id || "",
			href: "#",
		},
		node.attrs.label || "",
	],
}));

export const wikilinkView = $view(
	wikilinkSchema.node,
	(ctx): NodeViewConstructor =>
		(initialNode, view) => {
			let currentNode: ProseNode = initialNode;

			const config = ctx.get(wikilinkConfig.key);
			const dom = document.createElement("a");

			dom.className = "wikilink-node";
			dom.setAttribute("contenteditable", "false");
			dom.setAttribute("href", "#");

			const updateDisplay = (node: ProseNode) => {
				const id = String(node.attrs?.id ?? "");
				const storedLabel = String(node.attrs?.label ?? "");
				const page = config.getPageById(id);
				const displayLabel = resolveDisplayLabel(
					storedLabel,
					page?.title ?? "",
					id,
				);
				const href = page?.slug
					? `${config.rootPath}/${encodeSlugPath(page.slug)}`
					: "#";

				dom.textContent = displayLabel;
				dom.setAttribute("data-wikilink-id", id);
				dom.setAttribute("href", href);
				dom.title = displayLabel;
			};

			updateDisplay(currentNode);

			return {
				dom,
				update: (updatedNode) => {
					if (updatedNode.type !== currentNode.type) return false;
					currentNode = updatedNode;
					updateDisplay(updatedNode);
					return true;
				},
				selectNode: () => {
					dom.classList.add("is-selected");
				},
				deselectNode: () => {
					dom.classList.remove("is-selected");
				},
				stopEvent: () => false,
				ignoreMutation: () => true,
				destroy: () => {
					dom.remove();
				},
			};
		},
);

function resolveDisplayLabel(
	storedLabel: string,
	pageTitle: string,
	id: string,
): string {
	const label = storedLabel.trim();
	const title = pageTitle.trim();

	if (label !== "" && title !== "") {
		const segments = normalizeLabelSegments(label);
		if (segments.length === 0) return title;
		segments[segments.length - 1] = title;
		return segments.join("/");
	}

	if (label !== "") {
		const normalized = normalizeLabelSegments(label).join("/");
		return normalized === "" ? label : normalized;
	}
	if (title !== "") return title;
	if (id) return id;
	return "Untitled";
}

function normalizeLabelSegments(label: string): string[] {
	return label
		.split("/")
		.map((segment) => segment.trim())
		.filter((segment) => segment !== "")
		.map((segment) => titleizeSegment(segment));
}

function titleizeSegment(segment: string): string {
	const chars = Array.from(segment);
	if (chars.length === 0) return "";
	return chars[0].toUpperCase() + chars.slice(1).join("");
}
