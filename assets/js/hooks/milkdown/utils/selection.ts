import type { EditorView } from "prosemirror-view";

function isResolvedPosInHeading($pos: any) {
	if (!$pos) return false;
	for (let depth = $pos.depth; depth > 0; depth--) {
		if ($pos.node(depth)?.type?.name === "heading") return true;
	}
	return false;
}

export function isSelectionInHeading(view: EditorView): boolean {
	const selection: any = (view as any)?.state?.selection;
	if (!selection) return false;

	if (selection.node?.type?.name === "heading") return true;
	if (isResolvedPosInHeading(selection.$from)) return true;
	if (isResolvedPosInHeading(selection.$to)) return true;

	return false;
}
