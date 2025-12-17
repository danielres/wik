import assert from "node:assert/strict";
import { describe, test, beforeEach, afterEach } from "node:test";
import { JSDOM } from "jsdom";

import { markdownValidator } from "./markdown-validator.ts";

function wait(ms) {
	return new Promise((res) => setTimeout(res, ms));
}

describe("markdownValidator", () => {
	beforeEach(() => {
		const dom = new JSDOM("", { url: "https://example.org/" });
		global.window = dom.window;
	});

	afterEach(() => {
		delete global.window;
	});

	test("refresh returns ok with normalized markdown and calls callbacks", () => {
		const calls = { valid: [], after: [] };
		const v = markdownValidator({
			seedMarkdown: " Initial ",
			serialize: () => "  Hello  ",
			normalize: (s) => s.trim(),
			onValidMarkdown: (md) => calls.valid.push(md),
			onAfterRefresh: (result, { immediate }) =>
				calls.after.push({ result, immediate }),
		});

		const r = v.refresh({ immediate: true });
		assert.equal(r.ok, true);
		assert.equal(r.markdown, "Hello");
		assert.deepEqual(calls.valid, ["Hello"]);
		assert.equal(calls.after.length, 1);
		assert.equal(calls.after[0].result.ok, true);
		assert.equal(calls.after[0].immediate, true);
		assert.equal(v.isValid(), true);
		assert.equal(v.getLastGoodMarkdown(), "Hello");
	});

	test("refresh returns not ok when serializer throws and throttles errors", async () => {
		let errorCount = 0;
		const v = markdownValidator({
			seedMarkdown: "ok",
			serialize: () => {
				throw new Error("boom");
			},
			normalize: (s) => s,
			errorLogThrottleMs: 50,
			onError: () => {
				errorCount += 1;
			},
		});

		const r1 = v.refresh();
		assert.equal(r1.ok, false);
		assert.equal(v.isValid(), false);

		// Second call within throttle window should not call onError again
		const r2 = v.refresh();
		assert.equal(r2.ok, false);
		assert.equal(errorCount, 1);

		await wait(60);
		const r3 = v.refresh();
		assert.equal(r3.ok, false);
		assert.equal(errorCount, 2);
	});

	test("uses short debounce when valid, long debounce when invalid, and 0ms when immediate", async () => {
		const events = [];
		const requestedDelays = [];
		let shouldThrow = false;
		const v = markdownValidator({
			seedMarkdown: "seed",
			serialize: () => {
				if (shouldThrow) throw new Error("fail");
				return "A";
			},
			normalize: (s) => s,
			okDebounceMs: 10,
			failDebounceMs: 30,
			onAfterRefresh: (result) => events.push({ t: Date.now(), ok: result.ok }),
		});

		const originalSetTimeout = window.setTimeout.bind(window);
		const originalClearTimeout = window.clearTimeout.bind(window);

		window.setTimeout = (fn, ms) => {
			requestedDelays.push(ms);
			return originalSetTimeout(fn, 0);
		};
		window.clearTimeout = (timer) => originalClearTimeout(timer);

		try {
			// Start valid -> should use okDebounceMs
			v.scheduleValidation();
			await wait(0);
			assert.equal(events.length >= 1, true);
			assert.equal(events[0].ok, true);

			// Now fail -> should use failDebounceMs
			shouldThrow = true;
			v.refresh(); // set valid=false
			v.scheduleValidation();
			await wait(0);
			assert.equal(events.length >= 2, true);
			assert.equal(events[1].ok, false);

			// Immediate should schedule with 0ms
			shouldThrow = false;
			v.scheduleValidation({ immediate: true });
			await wait(0);
			assert.equal(events.length >= 3, true);
			assert.ok(typeof events[2].ok === "boolean");

			assert.deepEqual(requestedDelays, [10, 30, 0]);
		} finally {
			window.setTimeout = originalSetTimeout;
			window.clearTimeout = originalClearTimeout;
		}
	});
});
