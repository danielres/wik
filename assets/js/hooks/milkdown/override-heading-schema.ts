import type { MilkdownPlugin, TimerType } from "@milkdown/ctx";
import { createTimer } from "@milkdown/ctx";
import { nodesCtx, schemaTimerCtx } from "@milkdown/core";
import type { NodeSchema } from "@milkdown/transformer";

const OverrideHeadingSchemaReady = createTimer("OverrideHeadingSchemaReady");
const HEADING_CONTENT = "text*";
const HEADING_MARKS = "";

export const overrideHeadingSchema: MilkdownPlugin = (ctx) => {
	ctx.record(OverrideHeadingSchemaReady);
	ctx.update(schemaTimerCtx, (timers: TimerType[]) =>
		timers.concat(OverrideHeadingSchemaReady),
	);

	return async () => {
		try {
			ctx.update(nodesCtx, (nodes: Array<[string, NodeSchema]>) =>
				nodes.map(([id, node]) => {
					if (id !== "heading") return [id, node];

					return [
						id,
						{
							...node,
							content: HEADING_CONTENT,
							marks: HEADING_MARKS,
						},
					];
				}),
			);
		} finally {
			ctx.done(OverrideHeadingSchemaReady);
		}

		return () => {
			ctx.update(schemaTimerCtx, (timers: TimerType[]) =>
				timers.filter((t) => t !== OverrideHeadingSchemaReady),
			);
			ctx.clearTimer(OverrideHeadingSchemaReady);
		};
	};
};
