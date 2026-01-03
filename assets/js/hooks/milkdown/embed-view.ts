import type { Node as ProseNode } from "@milkdown/prose/model";
import type { NodeViewConstructor } from "@milkdown/prose/view";
import { $view } from "@milkdown/utils";

import { embedSchema, normalizeEmbedSource } from "./embed-node";

type EmbedProvider = "youtube" | "soundcloud";

type EmbedAttrs = {
	src: string;
	provider: EmbedProvider;
};

function resolveProvider(value: string): EmbedProvider {
	return value === "soundcloud" ? "soundcloud" : "youtube";
}

function embedTitle(provider: EmbedProvider): string {
	if (provider === "soundcloud") return "SoundCloud embed";
	return "YouTube embed";
}

function embedAllow(provider: EmbedProvider): string {
	if (provider === "soundcloud") return "autoplay";
	return "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share";
}

export const embedView = $view(
	embedSchema.node,
	(_ctx): NodeViewConstructor =>
		(initialNode, view, getPos) => {
			let currentNode: ProseNode = initialNode;
			let showingPlaceholder = false;

			const dom = document.createElement("div");
			dom.className = "milkdown-embed";

			const input = document.createElement("input");
			input.type = "url";
			input.placeholder = "Paste link (YouTube, SoundCloud)";
			input.autocomplete = "off";
			input.spellcheck = false;
			input.className = "milkdown-embed-input-field";
			input.setAttribute("aria-label", "Paste embed link");

			const button = document.createElement("button");
			button.type = "button";
			const buttonLabel = document.createElement("span");
			buttonLabel.textContent = "Insert";
			button.append(buttonLabel);
			button.className = "milkdown-embed-input-submit";

			const cancel = document.createElement("button");
			cancel.type = "button";
			const cancelLabel = document.createElement("span");
			cancelLabel.textContent = "Cancel";
			cancel.append(cancelLabel);
			cancel.className = "milkdown-embed-input-cancel";

			const form = document.createElement("div");
			form.className = "milkdown-embed-input";
			form.append(input, button, cancel);

			const iframe = document.createElement("iframe");
			iframe.className = "milkdown-embed-frame";
			iframe.setAttribute("loading", "lazy");
			iframe.setAttribute("referrerpolicy", "strict-origin-when-cross-origin");
			iframe.setAttribute("frameborder", "0");
			iframe.setAttribute("allowfullscreen", "true");

			const removePlaceholder = () => {
				const pos = getPos();
				if (pos == null) return;
				const tr = view.state.tr.delete(pos, pos + currentNode.nodeSize);
				view.dispatch(tr);
				view.focus();
			};

			const submit = () => {
				const value = input.value.trim();
				const normalized = normalizeEmbedSource(value);
				if (!normalized) return;
				const pos = getPos();
				if (pos == null) return;
				const attrs: EmbedAttrs = {
					src: normalized.src,
					provider: resolveProvider(normalized.provider),
				};
				const tr = view.state.tr.setNodeMarkup(pos, undefined, attrs);
				view.dispatch(tr.scrollIntoView());
				view.focus();
			};

			input.addEventListener("keydown", (event) => {
				if (event.key === "Enter") {
					event.preventDefault();
					event.stopPropagation();
					submit();
				}
			});

			button.addEventListener("click", (event) => {
				event.preventDefault();
				event.stopPropagation();
				submit();
			});

			cancel.addEventListener("click", (event) => {
				event.preventDefault();
				event.stopPropagation();
				removePlaceholder();
			});

			const renderPlaceholder = (src: string) => {
				showingPlaceholder = true;
				input.value = src;
				dom.setAttribute("data-embed-provider", "");
				dom.setAttribute("data-embed-src", src);
				dom.replaceChildren(form);
			};

			const renderEmbed = (attrs: EmbedAttrs) => {
				showingPlaceholder = false;
				const provider = resolveProvider(attrs.provider);
				dom.setAttribute("data-embed-provider", provider);
				dom.setAttribute("data-embed-src", attrs.src);
				iframe.src = attrs.src;
				iframe.title = embedTitle(provider);
				iframe.setAttribute("allow", embedAllow(provider));
				dom.replaceChildren(iframe);
			};

			const bind = (node: ProseNode) => {
				const src = String(node.attrs?.src ?? "");
				const normalized = normalizeEmbedSource(src);
				if (normalized) {
					renderEmbed({
						src: normalized.src,
						provider: resolveProvider(normalized.provider),
					});
					return;
				}

				renderPlaceholder(src);
			};

			bind(initialNode);

			return {
				dom,
				update: (updatedNode) => {
					if (updatedNode.type !== currentNode.type) return false;
					currentNode = updatedNode;
					bind(updatedNode);
					return true;
				},
				stopEvent: (event) =>
					event.target instanceof HTMLInputElement ||
					event.target instanceof HTMLButtonElement,
				selectNode: () => {
					dom.classList.add("is-selected");
					if (showingPlaceholder) {
						requestAnimationFrame(() => input.focus());
					}
				},
				deselectNode: () => {
					dom.classList.remove("is-selected");
				},
				ignoreMutation: () => true,
				destroy: () => {
					dom.remove();
				},
			};
		},
);
