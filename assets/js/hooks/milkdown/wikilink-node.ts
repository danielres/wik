import type { Ctx } from "@milkdown/ctx";
import type { Node as MarkdownNode } from "@milkdown/transformer";
import type { Node as ProseNode } from "@milkdown/prose/model";
import type { NodeViewConstructor } from "@milkdown/prose/view";

import { $ctx, $nodeSchema, $remark, $view } from "@milkdown/utils";
import { visit } from "unist-util-visit";

export type WikilinkConfig = {
	rootPath: string;
};

const WIKILINK_REGEX = /\[\[([^\]]+)\]\]/g;

function encodePath(path: string) {
	return path
		.split("/")
		.map((seg) => encodeURIComponent(seg))
		.join("/");
}

export const wikilinkConfig = $ctx<WikilinkConfig>(
	{
		rootPath: "",
	},
	"wikilinkConfig",
);

export const remarkWikilinkPlugin = $remark(
	"remark-wikilink",
	() => () => (tree: MarkdownNode) => {
		visit(tree, "text", (node: any, index: number, parent: any) => {
			if (!parent || typeof index !== "number") return;
			if (parent.type === "link" || parent.type === "inlineCode") return;
			if (parent.type === "code" || parent.type === "html") return;

			const value = typeof node.value === "string" ? node.value : "";
			if (!value.includes("[[")) return;

			const parts: any[] = [];
			let lastIndex = 0;
			let match: RegExpExecArray | null;

			WIKILINK_REGEX.lastIndex = 0;
			while ((match = WIKILINK_REGEX.exec(value))) {
				const raw = match[1] || "";
				const path = raw.trim();
				const start = match.index;
				const end = start + match[0].length;

				const before = value.slice(lastIndex, start);
				if (before) parts.push({ type: "text", value: before });

				if (path) {
					parts.push({ type: "wikilink", path });
				} else {
					parts.push({ type: "text", value: match[0] });
				}

				lastIndex = end;
			}

			if (parts.length === 0) return;

			const after = value.slice(lastIndex);
			if (after) parts.push({ type: "text", value: after });

			parent.children.splice(index, 1, ...parts);
			return [visit.SKIP, index + parts.length];
		});
	},
);

export const wikilinkSchema = $nodeSchema("wikilink", (_ctx: Ctx) => ({
	inline: true,
	group: "inline",
	atom: true,
	selectable: true,
	marks: "",
	attrs: {
		path: { default: "" },
	},
	parseMarkdown: {
		match: (node) => node.type === "wikilink",
		runner: (state, node, type) => {
			const path = String((node as any).path ?? "");
			if (!path) return;
			state.addNode(type, { path });
		},
	},
	toMarkdown: {
		match: (node) => node.type.name === "wikilink",
		runner: (state, node) => {
			const path = String(node.attrs.path ?? "");
			if (!path) return;
			state.addNode("text", undefined, `[[${path}]]`);
		},
	},
	parseDOM: [
		{
			tag: "a[data-wikilink-path]",
			priority: 100,
			getAttrs: (dom) => {
				if (!(dom instanceof HTMLElement)) return false;
				const path = dom.getAttribute("data-wikilink-path") || "";
				if (!path) return false;
				return { path };
			},
		},
	],
	toDOM: (node) => [
		"a",
		{
			class: "wikilink-node",
			"data-wikilink-path": node.attrs.path || "",
			href: "#",
		},
		node.attrs.path || "",
	],
}));

export const wikilinkView = $view(
	wikilinkSchema.node,
	(ctx): NodeViewConstructor =>
		(initialNode, _view) => {
			let currentNode: ProseNode = initialNode;

			const config = ctx.get(wikilinkConfig.key);
			const dom = document.createElement("a");

			dom.className = "wikilink-node";
			dom.setAttribute("contenteditable", "false");
			dom.setAttribute("href", "#");

			const updateDisplay = (node: ProseNode) => {
				const path = String(node.attrs?.path ?? "");
				const href = path ? `${config.rootPath}/${encodePath(path)}` : "#";

				dom.textContent = path;
				dom.setAttribute("data-wikilink-path", path);
				dom.setAttribute("href", href);
				dom.title = path;
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
