export type MarkdownValidationResult =
	| { ok: true; markdown: string }
	| { ok: false; markdown: null };

type Options = {
	seedMarkdown: string;
	serialize: () => string;
	normalize: (markdown: string) => string;
	okDebounceMs?: number;
	failDebounceMs?: number;
	errorLogThrottleMs?: number;
	onError?: (error: unknown) => void;
	onValidMarkdown?: (markdown: string) => void;
	onAfterRefresh?: (
		result: MarkdownValidationResult,
		opts: { immediate: boolean },
	) => void;
};

export type MarkdownValidator = {
	refresh: (opts?: { immediate?: boolean }) => MarkdownValidationResult;
	scheduleValidation: (opts?: { immediate?: boolean }) => void;
	isValid: () => boolean;
	getLastGoodMarkdown: () => string;
	destroy: () => void;
};

const DEFAULT_OK_DEBOUNCE_MS = 150;
const DEFAULT_FAIL_DEBOUNCE_MS = 500;
const DEFAULT_ERROR_LOG_THROTTLE_MS = 2000;

export function markdownValidator(options: Options): MarkdownValidator {
	const normalize = options.normalize;
	const okDebounceMs = options.okDebounceMs ?? DEFAULT_OK_DEBOUNCE_MS;
	const failDebounceMs = options.failDebounceMs ?? DEFAULT_FAIL_DEBOUNCE_MS;
	const errorLogThrottleMs =
		options.errorLogThrottleMs ?? DEFAULT_ERROR_LOG_THROTTLE_MS;

	let valid = true;
	let lastGoodMarkdown = normalize(options.seedMarkdown);
	let lastErrorAtMs = 0;
	let validationTimer: number | null = null;

	const validateNow = (): MarkdownValidationResult => {
		try {
			const current = normalize(options.serialize());
			valid = true;
			lastGoodMarkdown = current;
			options.onValidMarkdown?.(current);
			return { ok: true, markdown: current };
		} catch (e) {
			valid = false;
			const now = Date.now();
			if (now - lastErrorAtMs > errorLogThrottleMs) {
				options.onError?.(e);
				lastErrorAtMs = now;
			}
			return { ok: false, markdown: null };
		}
	};

	const refresh: MarkdownValidator["refresh"] = (opts) => {
		const immediate = opts?.immediate ?? false;
		const result = validateNow();
		options.onAfterRefresh?.(result, { immediate });
		return result;
	};

	const scheduleValidation: MarkdownValidator["scheduleValidation"] = (
		opts,
	) => {
		const immediate = opts?.immediate ?? false;
		if (validationTimer) window.clearTimeout(validationTimer);
		const delayMs = immediate ? 0 : valid ? okDebounceMs : failDebounceMs;
		validationTimer = window.setTimeout(() => {
			validationTimer = null;
			refresh({ immediate });
		}, delayMs);
	};

	const destroy = () => {
		if (validationTimer) window.clearTimeout(validationTimer);
		validationTimer = null;
	};

	return {
		refresh,
		scheduleValidation,
		isValid: () => valid,
		getLastGoodMarkdown: () => lastGoodMarkdown,
		destroy,
	};
}
