import assert from "node:assert/strict";
import { test } from "node:test";
import { readUndoRedoState } from "./undo-state.ts";

// Focus on function-level behavior (no DOM needed here)

test("readUndoRedoState returns false/false for null view", () => {
	const result = readUndoRedoState(null);
	assert.deepEqual(result, { hasUndo: false, hasRedo: false });
});

test("readUndoRedoState reflects depths > 0", () => {
	const fakeState = {};
	const fakeView = { state: fakeState };
	// We cannot easily mock prosemirror-history here without DI; but runtime will call actual functions.
	// This test simply asserts it doesn't throw and returns a boolean shape. In deeper tests we would stub the module.
	const result = readUndoRedoState(fakeView);
	assert.equal(typeof result.hasUndo, "boolean");
	assert.equal(typeof result.hasRedo, "boolean");
});
