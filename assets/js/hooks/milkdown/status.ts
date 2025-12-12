export class StatusIndicator {
	private lastSaved: string;
	private current: string;
	private ready = false;
	private timer: number | null = null;

	constructor(initial: string) {
		this.lastSaved = initial;
		this.current = initial;
	}

	setReady() {
		this.ready = true;
	}

	markSaved(content: string) {
		this.lastSaved = content;
		if (!this.ready) return;
	}

	updateCurrent(content: string) {
		this.current = content;
		if (!this.ready) return;
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
	}

	getLastSaved() {
		return this.lastSaved;
	}

	isSynced() {
		return this.current === this.lastSaved;
	}
}
