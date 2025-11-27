import { tableBlock } from "@milkdown/components/table-block";
import { Ctx, SliceType } from "@milkdown/ctx";
import { listItemBlockComponent } from "@milkdown/kit/component/list-item-block";
import {
	DefaultValue,
	defaultValueCtx,
	Editor,
	editorViewCtx,
	rootCtx,
} from "@milkdown/kit/core";
import { slashFactory, SlashProvider } from "@milkdown/kit/plugin/slash";
import {
	commonmark,
	createCodeBlockCommand,
} from "@milkdown/kit/preset/commonmark";
import { gfm, insertTableCommand } from "@milkdown/kit/preset/gfm";
import { callCommand } from "@milkdown/kit/utils";
import { getMarkdown } from "@milkdown/utils";

const slash = slashFactory("Commands");

const MilkdownEditor = {
	mounted() {
		const { markdown = "", editable, inputId } = this.el.dataset;

		this.hiddenInput = inputId ? document.getElementById(inputId) : null;
		this.form = this.el.closest("form");

		Editor.make()
			.config((ctx) => {
				ctx.set(rootCtx, this.el);
				ctx.set(defaultValueCtx, markdown);
				ctx.set(slash.key, {
					view: (view: any) => this.createSlashView(view),
				});
			})
			.use(commonmark)
			.use(gfm)
			.use(listItemBlockComponent)
			.use(tableBlock)
			.use(slash)
			.create()
			.then((editor) => {
				this.editorInstance = editor;
				this.setEditable(editable !== undefined);
				this.setupFormSync();
			});
	},

	createSlashView(_view: any) {
		const container = document.createElement("div");
		container.className =
			"absolute hidden data-[show='true']:grid w-64 gap-1 p-2 bg-base-300 rounded";
		this.el.appendChild(container);

		const provider = new SlashProvider({
			content: container,
		});

		// helper: delete "/" and run a Milkdown command
		const makeSlashHandler =
			(commandKey: any, payload?: any) => (e: MouseEvent | KeyboardEvent) => {
				e.preventDefault();
				e.stopPropagation();

				if (!this.editorInstance) return;

				this.editorInstance.action((ctx: Ctx) => {
					const view = ctx.get(editorViewCtx);
					const { dispatch, state } = view;
					const { tr, selection } = state;
					const { from } = selection;

					// delete the trigger `/`
					dispatch(tr.deleteRange(from - 1, from));

					return payload
						? callCommand(commandKey, payload)(ctx)
						: callCommand(commandKey)(ctx);
				});
			};

		// helper: create a styled button with handler
		const createButton = (label: string, handler: (e: any) => void) => {
			const button = document.createElement("button");
			button.type = "button";
			button.textContent = label;
			button.className =
				"btn btn-base hover:bg-base-100 border border-base-300 shadow";
			button.addEventListener("mousedown", handler);
			container.appendChild(button);
			return button;
		};

		const handleCodeBlock = makeSlashHandler(createCodeBlockCommand.key);
		const handleTable = makeSlashHandler(insertTableCommand.key);
		const button_code = createButton("Code Block", handleCodeBlock);
		const button_table = createButton("Table", handleTable);

		return {
			update: (updatedView: any, prevState: any) => {
				provider.update(updatedView, prevState);
			},
			destroy: () => {
				provider.destroy();
				button_code.removeEventListener("mousedown", handleCodeBlock);
				button_table.removeEventListener("mousedown", handleTable);
				container.remove();
			},
		};
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
