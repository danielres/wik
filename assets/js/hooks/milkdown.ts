import {
	defaultValueCtx,
	Editor,
	rootCtx,
	editorViewCtx,
} from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { getMarkdown } from "@milkdown/utils";

const MilkdownEditor = {
	mounted() {
		const markdown = this.el.dataset.markdown || "hello";
		const editable = this.el.dataset.editable !== undefined;
		const inputId = this.el.dataset.inputId;

		this.hiddenInput = inputId
			? (document.getElementById(inputId) as HTMLTextAreaElement | null)
			: null;
		this.form = this.el.closest("form");

		this.editor = Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, this.el);
				ctx.set(defaultValueCtx, markdown);
			})
			.use(commonmark)
			.create()
			.then((editor) => {
				this.editorInstance = editor;

				const view = editor.ctx.get(editorViewCtx);
				view.props.editable = () => editable;
				view.updateState(view.state);

				// on submit, write markdown into the hidden textarea
				if (this.form && this.hiddenInput) {
					console.log(this.form);
					this.handleSubmit = () => {
						const md = this.editorInstance.action(getMarkdown());
						this.hiddenInput.value = md;
						this.hiddenInput.dispatchEvent(
							new Event("input", { bubbles: true }),
						);
					};
					this.form.addEventListener("submit", this.handleSubmit);
				}

				return editor;
			});
	},

	updated() {
		if (!this.editorInstance) return;

		const editable = this.el.dataset.editable !== undefined;
		const markdown = this.el.dataset.markdown || "hello";

		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.props.editable = () => editable;
		view.updateState(view.state);

		if (markdown !== this.lastMarkdown) {
			this.editorInstance.action((ctx: any) => {
				ctx.set(defaultValueCtx, markdown);
			});
			this.lastMarkdown = markdown;
		}
	},

	destroyed() {
		if (this.form && this.handleSubmit) {
			this.form.removeEventListener("submit", this.handleSubmit);
		}
		this.editorInstance = null;
		this.editor = null;
		this.form = null;
		this.hiddenInput = null;
	},
};

export default MilkdownEditor;
