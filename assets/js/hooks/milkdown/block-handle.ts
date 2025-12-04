// assets/js/milkdown/block-handle.ts
import type { Ctx } from "@milkdown/ctx";
import { blockSpec, BlockProvider } from "@milkdown/kit/plugin/block"; // <- fixed import
import type { EditorView } from "@milkdown/kit/prose/view";
import type { PluginView, EditorState } from "@milkdown/kit/prose/state";

class BlockHandleView implements PluginView {
	private provider: BlockProvider;
	private handle: HTMLButtonElement;

	constructor(ctx: Ctx, _rootEl: HTMLElement) {
		const handle = document.createElement("button");
		handle.type = "button";
		handle.innerHTML = "⋮";
		handle.className = "milkdown-block-handle";
		this.handle = handle;

		this.provider = new BlockProvider({
			ctx,
			content: this.handle,
			getOffset: () => 4,
		});
	}

	update = (view: EditorView, prevState?: EditorState) => {
		this.provider.update(view, prevState);
	};

	destroy = () => {
		this.provider.destroy();
		this.handle.remove();
	};
}

export const setupBlockHandle = (ctx: Ctx, rootEl: HTMLElement) => {
	ctx.set(blockSpec.key, {
		view: () => new BlockHandleView(ctx, rootEl),
	});
};
