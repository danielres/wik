import assert from "node:assert/strict";
import { test } from "node:test";
import { StatusIndicator } from "./milkdown/status.ts";

// Simple StatusIndicator smoke tests

test("StatusIndicator marks unsaved when current != last saved and synced when equal", () => {
	const s = new StatusIndicator("Saved");
	// Not ready yet, but isSynced uses values only
	s.updateCurrent("Saved");
	assert.equal(s.isSynced(), true);
	s.updateCurrent("Changed");
	assert.equal(s.isSynced(), false);
	s.markSaved("Changed");
	assert.equal(s.isSynced(), true);
});
