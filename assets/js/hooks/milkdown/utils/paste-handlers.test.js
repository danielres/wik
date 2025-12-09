// Node built-in test runner; uses jsdom for DOM APIs.
const assert = require("node:assert/strict");
const { describe, test, beforeEach, afterEach } = require("node:test");
const { JSDOM } = require("jsdom");

const {
	makePasteNormalizers,
	configurePasteHandlers,
} = require("./paste-handlers.ts");

const ROOT = "/wiki";
const ORIGIN = "https://example.com";

beforeEach(() => {
	const dom = new JSDOM("", { url: `${ORIGIN}/current` });
	global.window = dom.window;
	global.document = dom.window.document;
	global.DOMParser = dom.window.DOMParser;
});

afterEach(() => {
	delete global.window;
	delete global.document;
	delete global.DOMParser;
});

describe("makePasteNormalizers", () => {
	test("transformText rewrites same-origin markdown links to root-relative", () => {
		const { transformText } = makePasteNormalizers(ROOT);
		const input = `[Foo](${ORIGIN}${ROOT}/Page)`;
		const result = transformText(input);
		assert.equal(result, `[Foo](${ROOT}/Page)`);
	});

	test("transformText leaves external links untouched", () => {
		const { transformText } = makePasteNormalizers(ROOT);
		const input = `[Foo](https://other.com${ROOT}/Page)`;
		assert.equal(transformText(input), input);
	});

	test("transformText bails out when host not present", () => {
		const { transformText } = makePasteNormalizers(ROOT);
		const input = `[Foo](/plain/path)`;
		assert.equal(transformText(input), input);
	});

	test("transformHtml rewrites same-origin anchors", () => {
		const { transformHtml } = makePasteNormalizers(ROOT);
		const input = `<a href="${ORIGIN}${ROOT}/Page?q=1#f">Link</a>`;
		const result = transformHtml(input);
		assert.equal(result, `<a href="${ROOT}/Page?q=1#f">Link</a>`);
	});

	test("transformHtml leaves external anchors untouched", () => {
		const { transformHtml } = makePasteNormalizers(ROOT);
		const input = `<a href="https://other.com${ROOT}/Page">Link</a>`;
		assert.equal(transformHtml(input), input);
	});
});

describe("configurePasteHandlers", () => {
	test("forwards args to previous handlers then normalizes", () => {
		let capturedArgs;
		const ctx = {
			update: (slice, updater) => {
				const updated = updater({
					transformPastedText: (text, plain, view) => {
						capturedArgs = { text, plain, view };
						return text;
					},
				});
				ctx.updated = updated;
			},
		};

		configurePasteHandlers(ctx, ROOT);

		const view = { id: "view" };
		const input = `[Foo](${ORIGIN}${ROOT}/Page)`;
		const output = ctx.updated.transformPastedText(input, true, view);

		assert.deepEqual(capturedArgs, { text: input, plain: true, view });
		assert.equal(output, `[Foo](${ROOT}/Page)`);
	});
});
