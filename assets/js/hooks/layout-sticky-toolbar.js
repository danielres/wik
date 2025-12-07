export const LayoutStickyToolbar = {
	mounted() {
		const el = this.el;
		const sentinel = document.getElementById("layout-sticky-toolbar-sentinel");
		if (!sentinel) return;

		this.observer = new IntersectionObserver(
			([entry]) => {
				const isPastTop =
					entry.boundingClientRect.top < 0 || entry.intersectionRatio === 0;
				el.classList.toggle("sticky-active-true", isPastTop);
			},
			{ threshold: [0, 1] },
		);

		this.observer.observe(sentinel);
	},
	destroyed() {
		this.observer?.disconnect();
	},
};
