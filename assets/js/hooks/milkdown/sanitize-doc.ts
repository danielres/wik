import { Fragment, Node as PMNode, Schema } from "@milkdown/kit/prose/model";
import { Plugin } from "@milkdown/kit/prose/state";
import { overrideTableSchema } from "./sanitize-doc/override-table-schema.ts";

// Usage:
// 1) `.use(overrideTableSchema)` after `.use(gfm)`.
// 2) Register `sanitizeDocPlugin` in `prosePluginsCtx`.

export type SanitizeDocResult = { node: PMNode; changed: boolean };

export const sanitizeDocPlugin = new Plugin({
	appendTransaction(trs, _oldState, newState) {
		if (!trs.some((tr) => tr.docChanged)) return null;

		const sanitized = sanitizeDoc(newState.doc, newState.schema);
		if (!sanitized.changed || sanitized.node.eq(newState.doc)) return null;

		return newState.tr.replaceWith(
			0,
			newState.doc.content.size,
			sanitized.node.content,
		);
	},
});

export { overrideTableSchema };

export function sanitizeDoc(node: PMNode, schema: Schema): SanitizeDocResult {
	if (node.isText) return { node, changed: false };

	const repairedRow = repairEmptyTableRow(node, schema);
	if (repairedRow) {
		return { node: repairedRow, changed: true };
	}

	if (!node.type.validContent(node.content)) {
		return { node: asFallback(node, schema), changed: true };
	}

	let changed = false;
	const children: PMNode[] = [];
	node.forEach((child: PMNode) => {
		const sanitizedChild = sanitizeDoc(child, schema);
		if (sanitizedChild.changed) changed = true;
		children.push(sanitizedChild.node);
	});

	if (!changed) return { node, changed: false };

	const content = Fragment.fromArray(children);
	if (!node.type.validContent(content)) {
		return { node: asFallback(node, schema), changed: true };
	}

	return {
		node: node.type.create(node.attrs, content, node.marks),
		changed: true,
	};
}

function asFallback(node: PMNode, schema: Schema): PMNode {
	return node.type === schema.topNodeType
		? asDoc(node, schema)
		: asParagraph(node, schema);
}

function asDoc(node: PMNode, schema: Schema): PMNode {
	const text = node.textContent || "";

	const paragraphType = schema.nodes.paragraph;
	if (paragraphType) {
		const paragraph = paragraphType.create(
			null,
			text ? schema.text(text) : null,
		);
		return schema.topNodeType.create(null, paragraph);
	}

	return schema.topNodeType.createAndFill() ?? node;
}

function asParagraph(node: PMNode, schema: Schema): PMNode {
	const text = node.textContent || "";
	return schema.nodes.paragraph.create(null, text ? schema.text(text) : null);
}

function repairEmptyTableRow(node: PMNode, schema: Schema): PMNode | null {
	if (node.childCount > 0) return null;

	if (node.type.name === "table_row") {
		const cell = schema.nodes.table_cell?.createAndFill();
		if (!cell) return null;
		return node.type.create(node.attrs, Fragment.fromArray([cell]), node.marks);
	}

	if (node.type.name === "table_header_row") {
		const cell = schema.nodes.table_header?.createAndFill();
		if (!cell) return null;
		return node.type.create(node.attrs, Fragment.fromArray([cell]), node.marks);
	}

	return null;
}
