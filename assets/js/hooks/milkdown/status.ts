export class StatusIndicator {
	private dot: HTMLElement | null;
	private label: HTMLElement | null;
	private lastSaved: string;
	private current: string;
	private ready = false;
	private timer: number | null = null;
	private statusDataTargetEl: HTMLElement;

	constructor(
		dot: HTMLElement | null,
		label: HTMLElement | null,
		initial: string,
		statusDataTargetEl: HTMLElement | null,
	) {
		this.dot = dot;
		this.label = label;
		this.lastSaved = initial;
		this.current = initial;
		if (!statusDataTargetEl) {
			throw new Error("StatusIndicator requires a statusDataTargetEl");
		}
		this.statusDataTargetEl = statusDataTargetEl;
	}

	setReady() {
		this.ready = true;
		this.render();
	}

	markSaved(content: string) {
		this.lastSaved = content;
		if (!this.ready) return;
		this.render();
	}

	updateCurrent(content: string) {
		this.current = content;
		if (!this.ready) return;
		this.render();
	}

	scheduleRefresh(fetchCurrent: () => string, delay = 200) {
		if (!this.ready || this.timer) return;

		this.timer = window.setTimeout(() => {
			this.timer = null;
			this.updateCurrent(fetchCurrent());
		}, delay);
	}

	// Exposed for cases where caller needs to force a render (e.g., after LV patch)
	refresh() {
		if (!this.ready) return;
		this.render();
	}

	private render() {
		if (!this.dot || !this.label) return;

		const dirty = this.current !== this.lastSaved;
		this.dot.classList.toggle("bg-emerald-500", !dirty);
		this.dot.classList.toggle("bg-rose-500", dirty);
		this.label.textContent = dirty ? "Unsaved changes" : "Synced";

		this.statusDataTargetEl.dataset.editorSynced = dirty ? "false" : "true";
	}
}
