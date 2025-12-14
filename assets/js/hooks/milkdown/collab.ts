import type { CollabService } from "@milkdown/plugin-collab";
import { WebsocketProvider } from "y-websocket";
import type { Doc } from "yjs";

type CollabOpts = {
	pageId?: string | null;
	seedMarkdown: string;
	editable: boolean;
	yDoc: Doc;
	collabService: CollabService;
	onReady: () => void;
};

export type CollabHandles = {
	destroy: () => void;
	wsProvider: WebsocketProvider | null;
	awareness: WebsocketProvider["awareness"] | null;
};

export function initCollab({
	pageId,
	seedMarkdown,
	editable,
	yDoc,
	collabService,
	onReady,
}: CollabOpts): CollabHandles {
	if (!pageId) {
		console.error("Milkdown collaboration requires pageId for room naming");
		return { destroy: () => {}, wsProvider: null, awareness: null };
	}

	const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
	const wsUrl = `${protocol}//${window.location.host}/collab`;
	const roomName = `page-${pageId}`;

	const wsProvider = new WebsocketProvider(wsUrl, roomName, yDoc);

	collabService.bindDoc(yDoc).setAwareness(wsProvider.awareness);

	wsProvider.once("synced", (isSynced) => {
		if (!isSynced) return;

		const metaMap = yDoc.getMap("meta");
		const seededVersion = metaMap.get("seeded_version_uuid");

		if (!seededVersion) {
			const myUUID = generateUUID();
			metaMap.set("seeded_version_uuid", myUUID);

			if (seedMarkdown && seedMarkdown.trim()) {
				collabService.applyTemplate(seedMarkdown);
			}
		}

		collabService.connect();
		onReady();

		if (editable) {
			// focus handled by caller
		}
	});

	return {
		wsProvider,
		awareness: wsProvider.awareness,
		destroy: () => {
			wsProvider.destroy();
		},
	};
}

function generateUUID(): string {
	// Polyfill for mobile

	if (
		typeof crypto !== "undefined" &&
		typeof crypto.randomUUID === "function"
	) {
		return crypto.randomUUID();
	}

	if (
		typeof crypto !== "undefined" &&
		typeof crypto.getRandomValues === "function"
	) {
		const bytes = crypto.getRandomValues(new Uint8Array(16));
		bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
		bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant

		const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
		return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
	}

	// Last-resort fallback (not cryptographically strong, but sufficient for client ids).
	return `uuid-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
