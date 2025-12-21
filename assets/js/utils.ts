export function capitalize(str: string): string {
	return str.charAt(0).toUpperCase() + str.substring(1).toLowerCase();
}

export function stringToPastelColor(str: string) {
	let hash = 0;
	for (let i = 0; i < str.length; i++) {
		hash = str.charCodeAt(i) + ((hash << 5) - hash);
		hash |= 0;
	}

	const hue = Math.abs(hash) % 360;
	const color = hslToHex(hue, 60, 55);

	return { color };
}

function hslToHex(h: number, s: number, l: number) {
	const sNorm = Math.max(0, Math.min(100, s)) / 100;
	const lNorm = Math.max(0, Math.min(100, l)) / 100;
	const c = (1 - Math.abs(2 * lNorm - 1)) * sNorm;
	const hPrime = (((h % 360) + 360) % 360) / 60;
	const x = c * (1 - Math.abs((hPrime % 2) - 1));
	const m = lNorm - c / 2;

	let r = 0;
	let g = 0;
	let b = 0;

	if (hPrime >= 0 && hPrime < 1) {
		r = c;
		g = x;
		b = 0;
	} else if (hPrime >= 1 && hPrime < 2) {
		r = x;
		g = c;
		b = 0;
	} else if (hPrime >= 2 && hPrime < 3) {
		r = 0;
		g = c;
		b = x;
	} else if (hPrime >= 3 && hPrime < 4) {
		r = 0;
		g = x;
		b = c;
	} else if (hPrime >= 4 && hPrime < 5) {
		r = x;
		g = 0;
		b = c;
	} else {
		r = c;
		g = 0;
		b = x;
	}

	const toHex = (v: number) => {
		const val = Math.round((v + m) * 255);
		return val.toString(16).padStart(2, "0");
	};

	return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}
