import { redoDepth, undoDepth } from "prosemirror-history";
import type { EditorView } from "prosemirror-view";

export function readUndoRedoState(view: EditorView | null): {
	hasUndo: boolean;
	hasRedo: boolean;
} {
	if (!view) {
		return { hasUndo: false, hasRedo: false };
	}

	const hasUndo = undoDepth(view.state) > 0;
	const hasRedo = redoDepth(view.state) > 0;

	return { hasUndo, hasRedo };
}
