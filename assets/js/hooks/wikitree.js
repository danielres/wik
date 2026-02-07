import Tree from "tui-tree";

const Wikitree = {
	mounted() {
		const raw = this.el.dataset.graph;
		if (!raw) return;

		this.buildTree(raw);

		this.handleEvent("wikitree_refresh", ({ graph }) => {
			if (!graph) return;
			this.buildTree(graph);
		});
	},
	destroyed() {
		if (this.tree && typeof this.tree.disableFeature === "function") {
			this.tree.disableFeature("Draggable");
		}
		this.tree = null;
	},
	buildTree(raw) {
		let data = [];
		try {
			data = JSON.parse(raw);
		} catch (error) {
			console.error("Invalid wikitree data", error);
			return;
		}

		this.el.dataset.graph = raw;
		this.el.innerHTML = "";
		this.tree = new Tree(this.el, {
			data,
			nodeDefaultState: "opened",
			usageStatistics: false,
		}).enableFeature("Draggable", {
			helperClassName: "tui-tree-drop",
			lineClassName: "tui-tree-line",
			isSortable: true,
		});

		this.tree.on("move", (eventData) => {
			const nodeId = eventData.nodeId;
			const nodeData = this.tree.getNodeData(nodeId);
			if (!nodeData || !nodeData.text) return;

			const nodeText = String(nodeData.text).trim();
			if (!nodeText) return;

			const originalParentPath = this.getPathFromNodeId(
				eventData.originalParentId,
			);
			const newParentPath = this.getPathFromNodeId(eventData.newParentId);
			const nodePath = [originalParentPath, nodeText].filter(Boolean).join("/");

			this.pushEvent(
				"wikitree_move",
				{
					node_path: nodePath,
					new_parent_path: newParentPath,
				},
				(reply) => {
					if (!reply?.ok) {
						window.location.reload();
					}
				},
			);
		});
	},
	getPathFromNodeId(nodeId) {
		if (!this.tree || !nodeId) return "";
		const rootId = this.tree.getRootNodeId();
		if (nodeId === rootId) return "";

		const parts = [];
		let currentId = nodeId;

		while (currentId && currentId !== rootId) {
			const data = this.tree.getNodeData(currentId);
			if (!data || !data.text) break;
			parts.push(String(data.text).trim());
			currentId = this.tree.getParentId(currentId);
		}

		return parts.reverse().filter(Boolean).join("/");
	},
};

export default Wikitree;
