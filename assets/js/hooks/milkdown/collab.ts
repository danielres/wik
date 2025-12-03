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
			const myUUID = crypto.randomUUID();
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
