import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { EditorState } from "@milkdown/kit/prose/state";
import { Schema } from "@milkdown/kit/prose/model";
import { sanitizeDoc, sanitizeDocPlugin } from "./sanitize-doc.ts";

function makeSchema() {
  return new Schema({
    nodes: {
      doc: { content: "block+" },
      paragraph: { content: "text*", group: "block" },
      text: { group: "inline" },
      // Simple table-ish nodes for exercising repair logic
      table_row: { content: "table_cell+", group: "block" },
      table_cell: { content: "paragraph" },
      table_header_row: { content: "table_header+", group: "block" },
      table_header: { content: "paragraph" },
    },
    marks: {},
  });
}

function createState(schema, doc) {
  return EditorState.create({
    schema,
    doc,
    plugins: [sanitizeDocPlugin],
  });
}

describe("sanitizeDocPlugin", () => {
  test("does not modify a valid document (smoke)", () => {
    const schema = makeSchema();
    const p = schema.nodes.paragraph.create(null, schema.text("ok"));
    const doc = schema.topNodeType.create(null, p);

    const state = createState(schema, doc);
    const tr = state.tr.insertText("!", 3); // change content; still valid
    const newState = state.apply(tr);

    assert.equal(newState.doc.eq(tr.doc), true);
  });

  test("repairs empty table_row by inserting a cell with a paragraph", () => {
    const schema = makeSchema();
    const emptyRow = schema.nodes.table_row.create();
    const p = schema.nodes.paragraph.create(null, schema.text("x"));
    const doc = schema.topNodeType.create(null, [p, emptyRow]);

    const sanitized = sanitizeDoc(doc, schema);
    assert.equal(sanitized.changed, true);

    // After sanitize, the row (second child) should have one cell with a paragraph
    const row = sanitized.node.child(1);
    assert.equal(row.type.name, "table_row");
    assert.equal(row.childCount, 1);
    const cell = row.child(0);
    assert.equal(cell.type.name, "table_cell");
    assert.equal(cell.child(0).type.name, "paragraph");
  });

  test("fallback replaces invalid top-level text with a paragraph", () => {
    const schema = makeSchema();
    // Top-level invalid text plus a valid paragraph
    const text = schema.text("hello");
    const p = schema.nodes.paragraph.create(null, schema.text("ok"));
    const doc = schema.topNodeType.create(null, [text, p]);

    const sanitized = sanitizeDoc(doc, schema);
    assert.equal(sanitized.changed, true);

    const top = sanitized.node;
    assert.equal(top.type, schema.topNodeType);
    // First child should be a paragraph after fallback
    assert.equal(top.child(0).type.name, "paragraph");
  });
});
