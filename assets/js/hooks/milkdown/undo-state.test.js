import assert from "node:assert/strict";
import { test } from "node:test";
import { EditorState } from "@milkdown/kit/prose/state";
import { Schema } from "@milkdown/kit/prose/model";
import { history } from "@milkdown/kit/prose/history";
import { readUndoRedoState } from "./undo-state.ts";

// Focus on function-level behavior (no DOM needed here)

test("readUndoRedoState returns false/false for null view", () => {
	const result = readUndoRedoState(null);
	assert.deepEqual(result, { hasUndo: false, hasRedo: false });
});

test("readUndoRedoState reflects depths > 0", () => {
	const schema = new Schema({
		nodes: {
			doc: { content: "text*" },
			text: { group: "inline" },
		},
		marks: {},
	});

	const state0 = EditorState.create({ schema, plugins: [history()] });
	const state1 = state0.apply(state0.tr.insertText("x"));

	const view = { state: state1 };
	const result = readUndoRedoState(view);

	assert.equal(result.hasUndo, true);
	assert.equal(result.hasRedo, false);
});
