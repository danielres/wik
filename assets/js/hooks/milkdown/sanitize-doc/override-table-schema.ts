import type { MilkdownPlugin, TimerType } from "@milkdown/ctx";
import { createTimer } from "@milkdown/ctx";
import { nodesCtx, schemaTimerCtx } from "@milkdown/core";
import type { NodeSchema } from "@milkdown/transformer";

const OverrideTableSchemaReady = createTimer("OverrideTableSchemaReady");
const TABLE_CELL_CONTENT = "paragraph";

export const overrideTableSchema: MilkdownPlugin = (ctx) => {
	ctx.record(OverrideTableSchemaReady);
	ctx.update(schemaTimerCtx, (timers: TimerType[]) =>
		timers.concat(OverrideTableSchemaReady),
	);

	return async () => {
		try {
			ctx.update(nodesCtx, (nodes: Array<[string, NodeSchema]>) =>
				nodes.map(([id, node]) => {
					if (id !== "table_cell" && id !== "table_header") return [id, node];

					return [id, { ...node, content: TABLE_CELL_CONTENT }];
				}),
			);
		} finally {
			ctx.done(OverrideTableSchemaReady);
		}

		return () => {
			ctx.update(schemaTimerCtx, (timers: TimerType[]) =>
				timers.filter((t) => t !== OverrideTableSchemaReady),
			);
			ctx.clearTimer(OverrideTableSchemaReady);
		};
	};
};
