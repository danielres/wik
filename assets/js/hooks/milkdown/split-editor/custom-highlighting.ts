import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

const splitEditorHighlightStyle = HighlightStyle.define([
	{ tag: tags.url, class: "cm-wik-url" },
	{ tag: tags.processingInstruction, class: "cm-wik-mark" },
	{ tag: tags.contentSeparator, class: "cm-wik-hr" },
]);

const splitEditorHighlighting = syntaxHighlighting(splitEditorHighlightStyle);

export { splitEditorHighlighting };
