import type { Ctx } from "@milkdown/ctx";
import type { Node as MarkdownNode } from "@milkdown/transformer";
import { $nodeSchema, $remark } from "@milkdown/utils";
import directive from "remark-directive";
import { visit } from "unist-util-visit";

export type EmbedProvider = "youtube" | "soundcloud";

export type EmbedAttrs = {
	src: string;
	provider: EmbedProvider;
};

const EMBED_DIRECTIVE_NAME = "embed";

function isHostAllowed(host: string, domain: string): boolean {
	return host === domain || host.endsWith(`.${domain}`);
}

function normalizeYouTubeUrl(url: URL): EmbedAttrs | null {
	const host = url.hostname.toLowerCase();
	const isYouTube =
		isHostAllowed(host, "youtube.com") ||
		isHostAllowed(host, "youtube-nocookie.com");
	const isShort = host === "youtu.be";
	if (!isYouTube && !isShort) return null;

	let videoId = "";
	let listId = url.searchParams.get("list") || "";

	if (isShort) {
		videoId = url.pathname.replace(/^\/+/, "").split("/")[0] || "";
	} else if (url.pathname.startsWith("/embed/")) {
		videoId = url.pathname.replace("/embed/", "").split("/")[0] || "";
	} else if (url.pathname === "/watch") {
		videoId = url.searchParams.get("v") || "";
	} else if (url.pathname.startsWith("/shorts/")) {
		videoId = url.pathname.replace("/shorts/", "").split("/")[0] || "";
	} else if (url.pathname === "/playlist") {
		listId = listId || url.searchParams.get("list") || "";
	}

	if (!videoId && !listId) return null;

	const base = videoId
		? `https://www.youtube.com/embed/${videoId}`
		: "https://www.youtube.com/embed/videoseries";
	const params = new URLSearchParams();
	if (listId) params.set("list", listId);

	const src = params.toString() ? `${base}?${params}` : base;

	return { provider: "youtube", src };
}

function normalizeSoundCloudUrl(url: URL): EmbedAttrs | null {
	const host = url.hostname.toLowerCase();
	const isEmbedHost = host === "w.soundcloud.com";

	if (isEmbedHost) {
		const raw = url.searchParams.get("url") || "";
		if (!raw) return null;
		try {
			const inner = new URL(raw);
			if (
				!isHostAllowed(inner.hostname.toLowerCase(), "soundcloud.com") &&
				!isHostAllowed(inner.hostname.toLowerCase(), "api.soundcloud.com")
			) {
				return null;
			}
			const normalized = `https://w.soundcloud.com/player/?url=${encodeURIComponent(
				inner.toString(),
			)}`;
			return { provider: "soundcloud", src: normalized };
		} catch (_e) {
			return null;
		}
	}

	if (
		!isHostAllowed(host, "soundcloud.com") &&
		!isHostAllowed(host, "api.soundcloud.com")
	) {
		return null;
	}

	if (!url.pathname || url.pathname === "/") return null;

	const src = `https://w.soundcloud.com/player/?url=${encodeURIComponent(
		url.toString(),
	)}`;

	return { provider: "soundcloud", src };
}

export function normalizeEmbedSource(
	raw: string | null | undefined,
): EmbedAttrs | null {
	const value = String(raw || "").trim();
	if (!value) return null;

	let url: URL;
	try {
		url = new URL(value);
	} catch (_e) {
		return null;
	}

	return normalizeYouTubeUrl(url) || normalizeSoundCloudUrl(url);
}

function extractIframeSrc(html: string): string | null {
	if (!html || !html.toLowerCase().includes("iframe")) return null;
	if (typeof DOMParser === "undefined") return null;

	const doc = new DOMParser().parseFromString(html, "text/html");
	const iframe = doc.body?.querySelector("iframe");
	if (!iframe) return null;

	const elements = Array.from(doc.body?.children || []);
	if (elements.length !== 1 || elements[0] !== iframe) return null;

	return iframe.getAttribute("src");
}

function toEmbedNode(rawSrc: string | null | undefined) {
	const normalized = normalizeEmbedSource(rawSrc);
	if (!normalized) return null;

	return {
		type: "embed",
		src: normalized.src,
		provider: normalized.provider,
	};
}

function toFallbackParagraph(rawSrc: string | null | undefined) {
	const src = String(rawSrc || "").trim();
	const value = src
		? `::${EMBED_DIRECTIVE_NAME}{src="${src}"}`
		: `::${EMBED_DIRECTIVE_NAME}{}`;

	return {
		type: "paragraph",
		children: [{ type: "text", value }],
	};
}

export function embedTitle(provider: EmbedProvider): string {
	if (provider === "soundcloud") return "SoundCloud embed";
	return "YouTube embed";
}

export function embedAllow(provider: EmbedProvider): string {
	if (provider === "soundcloud") return "autoplay";
	return "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share";
}

export const remarkEmbedDirective = $remark("remark-embed-directive", () => directive);

export const remarkEmbedPlugin = $remark(
	"remark-embed",
	() => () => (tree: MarkdownNode) => {
		visit(tree, ["leafDirective", "html"], (node: any, index: number, parent: any) => {
			if (!parent || typeof index !== "number") return;

			if (node.type === "leafDirective" && node.name === EMBED_DIRECTIVE_NAME) {
				const attrs = node.attributes || {};
				const embedNode = toEmbedNode(attrs.src);
				parent.children.splice(
					index,
					1,
					embedNode ?? toFallbackParagraph(attrs.src),
				);
				return;
			}

			if (node.type === "html") {
				const src = extractIframeSrc(String(node.value || ""));
				const embedNode = toEmbedNode(src);
				if (embedNode) parent.children.splice(index, 1, embedNode);
			}
		});
	},
);

export const embedSchema = $nodeSchema("embed", (_ctx: Ctx) => ({
	group: "block",
	atom: true,
	isolating: true,
	selectable: true,
	marks: "",
	attrs: {
		src: { default: "" },
		provider: { default: "" },
	},
	parseMarkdown: {
		match: (node) => node.type === "embed",
		runner: (state, node, type) => {
			const src = String((node as any).src ?? "");
			const provider = String((node as any).provider ?? "");
			if (!src || !provider) return;
			state.addNode(type, { src, provider });
		},
	},
	toMarkdown: {
		match: (node) => node.type.name === "embed",
		runner: (state, node) => {
			const src = String(node.attrs.src ?? "");
			if (!src) return;
			state.addNode("leafDirective", undefined, undefined, {
				name: EMBED_DIRECTIVE_NAME,
				attributes: { src },
			});
		},
	},
	parseDOM: [
		{
			tag: "div.milkdown-embed[data-embed-src]",
			getAttrs: (dom) => {
				if (!(dom instanceof HTMLElement)) return false;
				const src = dom.getAttribute("data-embed-src");
				const normalized = normalizeEmbedSource(src);
				return normalized ?? false;
			},
		},
		{
			tag: "iframe",
			getAttrs: (dom) => {
				if (!(dom instanceof HTMLElement)) return false;
				const normalized = normalizeEmbedSource(dom.getAttribute("src"));
				return normalized ?? false;
			},
		},
	],
	toDOM: (node) => {
		const src = String(node.attrs.src ?? "");
		const provider = String(node.attrs.provider ?? "") as EmbedProvider;
		const normalized = normalizeEmbedSource(src);
		const safeSrc = normalized?.src || "";
		const safeProvider = normalized?.provider || provider || "youtube";

		return [
			"div",
			{
				class: "milkdown-embed",
				"data-embed-provider": safeProvider,
				"data-embed-src": safeSrc,
			},
			[
				"iframe",
				{
					class: "milkdown-embed-frame",
					src: safeSrc,
					title: embedTitle(safeProvider),
					loading: "lazy",
					allow: embedAllow(safeProvider),
					referrerpolicy: "strict-origin-when-cross-origin",
					frameborder: "0",
					allowfullscreen: "true",
				},
			],
		];
	},
}));
