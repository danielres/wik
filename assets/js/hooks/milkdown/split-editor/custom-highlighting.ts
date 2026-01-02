import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { EditorState, type Extension } from "@codemirror/state";
import { tags } from "@lezer/highlight";

const splitEditorHighlightStyle = HighlightStyle.define([
	{ tag: tags.url, class: "cm-wik-url" },
	{ tag: tags.processingInstruction, class: "cm-wik-mark" },
	{ tag: tags.contentSeparator, class: "cm-wik-hr" },
]);

const splitEditorHighlighting = syntaxHighlighting(splitEditorHighlightStyle);

type EditableRef = { value: boolean };

const EDITOR_MUTATION_EVENTS = [
	"input",
	"delete",
	"paste",
	"cut",
	"undo",
	"redo",
	"move",
];

function createSplitEditorEditableExtension(editableRef: EditableRef): Extension {
	return EditorState.changeFilter.of((transaction) => {
		if (editableRef.value) return true;
		if (!transaction.docChanged) return true;

		const isUserMutation = EDITOR_MUTATION_EVENTS.some((event) =>
			transaction.isUserEvent(event),
		);

		return !isUserMutation;
	});
}

export { createSplitEditorEditableExtension, splitEditorHighlighting };
