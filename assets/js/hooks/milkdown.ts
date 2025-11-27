import { SliceType } from "@milkdown/ctx";
import {
	defaultValueCtx,
	Editor,
	rootCtx,
	editorViewCtx,
	DefaultValue,
} from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { getMarkdown } from "@milkdown/utils";

const MilkdownEditor = {
	mounted() {
		const { markdown = "", editable, inputId } = this.el.dataset;

		this.hiddenInput = inputId ? document.getElementById(inputId) : null;
		this.form = this.el.closest("form");

		Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, this.el);
				ctx.set(defaultValueCtx, markdown);
			})
			.use(commonmark)
			.create()
			.then((editor) => {
				this.editorInstance = editor;
				this.setEditable(editable !== undefined);
				this.setupFormSync();
			});
	},

	setEditable(editable: any) {
		const view = this.editorInstance.ctx.get(editorViewCtx);
		view.props.editable = () => editable;
		view.updateState(view.state);
	},

	setupFormSync() {
		if (this.form && this.hiddenInput) {
			this.handleSubmit = () => {
				this.hiddenInput.value = this.editorInstance.action(getMarkdown());
				this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
			};
			this.form.addEventListener("submit", this.handleSubmit);
		}
	},

	updated() {
		if (!this.editorInstance) return;

		this.setEditable(this.el.dataset.editable !== undefined);

		const markdown = this.el.dataset.markdown || "";
		if (markdown !== this.lastMarkdown) {
			this.editorInstance.action(
				(ctx: {
					set: (
						arg0: SliceType<DefaultValue, "defaultValue">,
						arg1: any,
					) => any;
				}) => ctx.set(defaultValueCtx, markdown),
			);
			this.lastMarkdown = markdown;
		}
	},

	destroyed() {
		this.form?.removeEventListener("submit", this.handleSubmit);
		this.editorInstance = null;
		this.form = null;
		this.hiddenInput = null;
	},
};

export default MilkdownEditor;
