export class StatusIndicator {
	private lastSaved: string;
	private current: string;
	private ready = false;

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
