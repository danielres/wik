// Lightweight force-directed graph renderer for wiki map
const CONFIG = {
	physics: {
		repel: 40000,
		spring: 0.22,
		damping: 0.86,
		springLength: 90,
		step: 0.03,
	},
	stop: {
		energyThreshold: 1e-3,
		stableFrames: 180,
	},
	node: {
		radius: 5,
		color: "#7dd3fc",
		missingColor: "#fca5a5",
	},
	edge: {
		color: "rgba(255,255,255,0.35)",
		width: 1.25,
		arrowSize: 10,
		arrowStroke: "rgba(0,0,0,0.25)",
	},
	label: {
		font: "12px sans-serif",
		color: "#e5e7eb",
		paddingX: 10,
		paddingY: 8,
	},
	hit: {
		radius: 10,
	},
};

const Wikimap = {
	mounted() {
		const data = this.el.dataset.graph;
		if (!data) return;
		try {
			this.graph = JSON.parse(data);
		} catch (e) {
			console.error("Invalid wikimap graph data", e);
			return;
		}
		this.setupCanvas();
		this.initPositions();
		this.energyBelowThresholdFor = 0;
		this.loop();
	},
	destroyed() {
		cancelAnimationFrame(this.rafId);
		this.canvas?.removeEventListener("mousemove", this._hoverHandler);
		this.canvas?.removeEventListener("click", this._clickHandler);
		this.canvas?.removeEventListener("mousedown", this._dragStartHandler);
		window.removeEventListener("mousemove", this._dragMoveHandler);
		window.removeEventListener("mouseup", this._dragEndHandler);
		window.removeEventListener("resize", this.resizeHandler);
	},
	setupCanvas() {
		this.canvas = document.createElement("canvas");
		this.canvas.className = "w-full h-full";
		this.el.innerHTML = "";
		this.el.appendChild(this.canvas);
		this.ctx = this.canvas.getContext("2d");
		const resize = () => {
			const rect = this.el.getBoundingClientRect();
			this.width = rect.width;
			this.height = rect.height;
			this.canvas.width = rect.width * devicePixelRatio;
			this.canvas.height = rect.height * devicePixelRatio;
			this.ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
		};
		resize();
		this.resizeHandler = resize;
		window.addEventListener("resize", resize);
		this.scale = 1;
		this.offset = { x: 0, y: 0 };
		this._clickHandler = (e) => this.handleClick(e);
		this._hoverHandler = (e) => this.handleHover(e);
		this._dragStartHandler = (e) => this.handleDragStart(e);
		this._dragMoveHandler = (e) => this.handleDragMove(e);
		this._dragEndHandler = () => this.handleDragEnd();
		this.canvas.addEventListener("click", this._clickHandler);
		this.canvas.addEventListener("mousemove", this._hoverHandler);
		this.canvas.addEventListener("mousedown", this._dragStartHandler);
		window.addEventListener("mousemove", this._dragMoveHandler);
		window.addEventListener("mouseup", this._dragEndHandler);
	},
	initPositions() {
		this.pos = {};
		this.vel = {};
		this.graph.nodes.forEach((n, i) => {
			this.pos[n.id] = {
				x: (Math.random() - 0.5) * 400 + i,
				y: (Math.random() - 0.5) * 400 + i,
			};
			this.vel[n.id] = { x: 0, y: 0 };
		});
	},
	loop() {
		const tick = () => {
			this.step();
			this.draw();
			this.rafId = requestAnimationFrame(tick);
		};
		tick();
	},
	step() {
		const { physics, stop } = CONFIG;
		const nodes = this.graph.nodes;
		const edges = this.graph.edges;

		// repulsion O(n^2)
		for (let i = 0; i < nodes.length; i++) {
			for (let j = i + 1; j < nodes.length; j++) {
				const a = nodes[i],
					b = nodes[j];
				const pa = this.pos[a.id],
					pb = this.pos[b.id];
				const dx = pa.x - pb.x,
					dy = pa.y - pb.y;
				const dist2 = dx * dx + dy * dy + 0.01;
				const force = physics.repel / dist2;
				const invDist = 1 / Math.sqrt(dist2);
				const fx = force * dx * invDist;
				const fy = force * dy * invDist;
				this.vel[a.id].x += fx;
				this.vel[a.id].y += fy;
				this.vel[b.id].x -= fx;
				this.vel[b.id].y -= fy;
			}
		}

		// springs
		edges.forEach((e) => {
			const pa = this.pos[e.source];
			const pb = this.pos[e.target];
			if (!pa || !pb) return;
			const dx = pb.x - pa.x,
				dy = pb.y - pa.y;
			const dist = Math.sqrt(dx * dx + dy * dy) || 0.001;
			const force = physics.spring * (dist - physics.springLength);
			const fx = (force * dx) / dist;
			const fy = (force * dy) / dist;
			this.vel[e.source].x += fx;
			this.vel[e.source].y += fy;
			this.vel[e.target].x -= fx;
			this.vel[e.target].y -= fy;
		});

		// integrate with damping
		nodes.forEach((n) => {
			const v = this.vel[n.id];
			const p = this.pos[n.id];
			p.x += v.x * physics.step;
			p.y += v.y * physics.step;
			v.x *= physics.damping;
			v.y *= physics.damping;
		});

		// stop when kinetic energy is very low for sustained frames
		const energy =
			nodes.reduce((acc, n) => {
				const v = this.vel[n.id];
				return acc + v.x * v.x + v.y * v.y;
			}, 0) / Math.max(nodes.length, 1);

		if (energy < stop.energyThreshold) {
			this.energyBelowThresholdFor = (this.energyBelowThresholdFor || 0) + 1;
		} else {
			this.energyBelowThresholdFor = 0;
		}

		if (this.energyBelowThresholdFor > stop.stableFrames && this.rafId) {
			cancelAnimationFrame(this.rafId);
			this.rafId = null;
		}
	},

	handleClick(event) {
		const rect = this.canvas.getBoundingClientRect();
		const relX = event.clientX - rect.left; // CSS pixels
		const relY = event.clientY - rect.top; // CSS pixels
		const x = (relX - this.width / 2 - this.offset.x) / this.scale;
		const y = (relY - this.height / 2 - this.offset.y) / this.scale;
		const hit = this.pickNode(x, y);
		if (hit && hit.slug) {
			const groupSlug =
				this.graph.group_slug || this.el.dataset.groupSlug || "";
			const url = `/${groupSlug}/wiki/${encodeURIComponent(hit.slug)}`;
			window.open(url, "_blank");
		}
	},
	handleHover(event) {
		const rect = this.canvas.getBoundingClientRect();
		const relX = event.clientX - rect.left; // CSS pixels
		const relY = event.clientY - rect.top; // CSS pixels
		const x = (relX - this.width / 2 - this.offset.x) / this.scale;
		const y = (relY - this.height / 2 - this.offset.y) / this.scale;
		const over = !!this.pickNode(x, y);
		this.canvas.style.cursor = over ? "pointer" : "default";
	},
	handleDragStart(event) {
		this.dragging = true;
		this.dragStart = { x: event.clientX, y: event.clientY };
		this.startOffset = { ...this.offset };
		this.canvas.style.cursor = "grabbing";
	},
	handleDragMove(event) {
		if (!this.dragging) return;
		const dx = event.clientX - this.dragStart.x;
		const dy = event.clientY - this.dragStart.y;
		this.offset.x = this.startOffset.x + dx;
		this.offset.y = this.startOffset.y + dy;
	},
	handleDragEnd() {
		this.dragging = false;
		this.canvas.style.cursor = "default";
	},
	pickNode(x, y) {
		const { hit, label } = CONFIG;
		const hitRadius2 = hit.radius * hit.radius;
		this.ctx.font = label.font;
		for (const n of this.graph.nodes) {
			const p = this.pos[n.id];
			const dx = p.x - x;
			const dy = p.y - y;
			if (dx * dx + dy * dy <= hitRadius2) return n;

			const text = n.label || "";
			const width = this.ctx.measureText(text).width;
			const x0 = p.x + label.paddingX;
			const x1 = x0 + width;
			const y0 = p.y - label.paddingY;
			const y1 = p.y + label.paddingY;
			if (x >= x0 && x <= x1 && y >= y0 && y <= y1) return n;
		}
		return null;
	},
	draw() {
		const { edge, node, label } = CONFIG;
		const ctx = this.ctx;
		ctx.clearRect(0, 0, this.width, this.height);
		ctx.save();
		ctx.translate(
			this.width / 2 + this.offset.x,
			this.height / 2 + this.offset.y,
		);
		ctx.scale(this.scale, this.scale);

		// edges (lines)
		ctx.strokeStyle = edge.color;
		ctx.lineWidth = edge.width;
		this.graph.edges.forEach((e) => {
			const a = this.pos[e.source];
			const b = this.pos[e.target];
			if (!a || !b) return;
			ctx.beginPath();
			ctx.moveTo(a.x, a.y);
			ctx.lineTo(b.x, b.y);
			ctx.stroke();
		});

		// nodes
		this.graph.nodes.forEach((n) => {
			const p = this.pos[n.id];
			ctx.beginPath();
			ctx.fillStyle = n.exists ? node.color : node.missingColor;
			ctx.arc(p.x, p.y, node.radius, 0, Math.PI * 2);
			ctx.fill();

			ctx.save();
			ctx.fillStyle = label.color;
			ctx.font = label.font;
			ctx.textBaseline = "middle";
			// Keep text size stable when zoomed
			const invScale = 1 / this.scale;
			ctx.scale(invScale, invScale);
			ctx.fillText(
				n.label,
				(p.x + label.paddingX) * this.scale,
				p.y * this.scale,
			);
			ctx.restore();
		});

		// arrowheads on top of nodes
		this.graph.edges.forEach((e) => {
			const a = this.pos[e.source];
			const b = this.pos[e.target];
			if (!a || !b) return;
			const dx = b.x - a.x;
			const dy = b.y - a.y;
			const len = Math.sqrt(dx * dx + dy * dy) || 1;
			const ux = dx / len;
			const uy = dy / len;

			// tip just before the target node edge
			const tipX = b.x - ux * node.radius;
			const tipY = b.y - uy * node.radius;
			const baseX = tipX - ux * edge.arrowSize;
			const baseY = tipY - uy * edge.arrowSize;
			const leftX = baseX - uy * (edge.arrowSize * 0.6);
			const leftY = baseY + ux * (edge.arrowSize * 0.6);
			const rightX = baseX + uy * (edge.arrowSize * 0.6);
			const rightY = baseY - ux * (edge.arrowSize * 0.6);

			ctx.beginPath();
			ctx.moveTo(tipX, tipY);
			ctx.lineTo(leftX, leftY);
			ctx.lineTo(rightX, rightY);
			ctx.closePath();
			ctx.fillStyle = edge.color;
			ctx.strokeStyle = edge.arrowStroke;
			ctx.fill();
			ctx.stroke();
		});
		ctx.restore();
	},
};

export default Wikimap;
