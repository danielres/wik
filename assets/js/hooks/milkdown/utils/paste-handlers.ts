import { editorViewOptionsCtx } from "@milkdown/core";
import type { Ctx } from "@milkdown/ctx";
import type { EditorView } from "@milkdown/prose/view";

export type PasteNormalizers = {
	transformText: (text: string) => string;
	transformHtml: (html: string) => string;
};

export const makePasteNormalizers = (rootPath: string): PasteNormalizers => {
	const transformText = (text: string) => {
		if (!text) return text;
		const pattern = /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/gi;
		return text.replace(pattern, (full, label, href) => {
			const normalized = stripDomain(href, rootPath);
			return normalized ? `[${label}](${normalized})` : full;
		});
	};

	const transformHtml = (html: string) => {
		if (!html) return html;
		// Early bailout: no links to process
		if (!html.includes('<a') && !html.includes('href=')) return html;
		const parser = new DOMParser();
		const doc = parser.parseFromString(html, "text/html");
		doc.querySelectorAll("a[href]").forEach((a) => {
			const href = a.getAttribute("href") || "";
			const normalized = stripDomain(href, rootPath);
			if (normalized) a.setAttribute("href", normalized);
		});
		return doc.body.innerHTML;
	};

	return { transformText, transformHtml };
};

export function configurePasteHandlers(ctx: Ctx, rootPath: string) {
	const { transformText, transformHtml } = makePasteNormalizers(rootPath);

	ctx.update(editorViewOptionsCtx, (prev) => ({
		...prev,
		transformPastedText: (text: string, plain: boolean, view: EditorView) => {
			const incoming = prev?.transformPastedText
				? prev.transformPastedText(text, plain, view)
				: text;
			return transformText(incoming);
		},
		transformPastedHTML: (html: string, view: EditorView) => {
			const incoming = prev?.transformPastedHTML
				? prev.transformPastedHTML(html, view)
				: html;
			return transformHtml(incoming);
		},
	}));
}

function stripDomain(href: string, rootPath: string): string | null {
	if (!href) return null;

	// Already normalized to our root path.
	if (href === rootPath || href.startsWith(rootPath + '/')) return href;

	// Convert only when the pasted link matches the current origin.
	try {
		const url = new URL(href, window.location.href);
		if (url.origin !== window.location.origin) return null;
		if (url.pathname.startsWith(rootPath)) {
			return `${url.pathname}${url.search}${url.hash}`;
		}
	} catch (_e) {
		return null;
	}

	return null;
}
