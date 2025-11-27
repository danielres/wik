import {
	defaultValueCtx,
	Editor,
	rootCtx,
	editorViewCtx,
} from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";

const MilkdownEditor = {
	mounted() {
		const markdown = this.el.dataset.markdown || "hello";
		const editable = this.el.dataset.editable !== undefined;

		this.editor = Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, "#milkdown-editor");
				ctx.set(defaultValueCtx, markdown);
			})
			.use(commonmark)
			.create()
			.then((editor) => {
				// Store the editor instance for later updates
				this.editorInstance = editor;

				// Set initial editable state
				const view = editor.ctx.get(editorViewCtx);
				view.props.editable = () => editable;
				view.updateState(view.state);

				return editor;
			});
	},

	updated() {
		if (!this.editorInstance) return;

		const editable = this.el.dataset.editable !== undefined;
		const markdown = this.el.dataset.markdown || "hello";

		// Update editable state without recreating editor
		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.props.editable = () => editable;
		view.updateState(view.state);

		// Only update markdown content if it actually changed
		if (markdown !== this.lastMarkdown) {
			this.editorInstance.action((ctx) => {
				ctx.set(defaultValueCtx, markdown);
			});
			this.lastMarkdown = markdown;
		}
	},

	destroyed() {
		this.editorInstance = null;
		this.editor = null;
	},
};

export default MilkdownEditor;
