let Hooks = {};

Hooks.HtmlDiffer = {
    mounted() { this.execute() },
    updated() { this.execute() },
    execute() {
        const original = document.getElementById("html_differ-original")
        const revised = document.getElementById("html_differ-revised")
        const diff = document.getElementById("html_differ-diff")
        if (!(original && revised && diff)) return;
        diff.innerHTML = window.differ(original.innerHTML, revised.innerHTML)
    },
}

Hooks.ShortcutComponent = {
    mounted() {
        this.abortController = new AbortController();
        const { signal } = this.abortController;
        const shortcutKey = this.el.getAttribute("phx-hook-shortcut-key");
        const firstChild = this.el.querySelector(":first-child");

        document.addEventListener("keydown", (e) => {
            if (e.key === "Alt") {
                e.preventDefault();
                const focusedElement = document.activeElement;
                const hint = this.el.querySelector(".hint");
                if (hint) hint.classList.remove("hidden");
            }

            if (e.altKey && e.key === shortcutKey) {
                e.preventDefault();
                firstChild.focus();
                firstChild.click();
            };
        }, { signal });

        document.addEventListener("keyup", (e) => {
            const hint = this.el.querySelector(".hint");
            if (hint) hint.classList.add("hidden");
        }, { signal });
    },
    destroyed() { this.abortController.abort() }
};

Hooks.ShowSuggestionsOnKeyup = {
    mounted() {
        this.abortController = new AbortController();
        const { signal } = this.abortController;

        // Keyup listener for suggestion generation
        this.el.addEventListener("keyup", (e) => {
            const textarea = this.el;
            const value = textarea.value;
            const cursor = textarea.selectionStart;

            const lineBeforeCursor = value.substring(0, cursor).split("\n").pop();
            const lineAfterCursor = value.substring(cursor, value.length).split("\n").shift();
            const lineBeforeWithoutLinks = lineBeforeCursor.replace(/\[\[([^\]]*)\]\]/g, "");
            const lineAfterWithoutLinks = lineAfterCursor.replace(/\[\[([^\]]*)\]\]/g, "");

            const characterBeforeCursor = value.substring(cursor - 1, cursor);
            const characterAfterCursor = value.substring(cursor, cursor + 1);
            const isWithinOpeningDelimiters = characterBeforeCursor === "[" && characterAfterCursor === "[";
            const isWithinClosingDelimiters = characterBeforeCursor === "]" && characterAfterCursor === "]";
            const isWithinDelimiters = isWithinOpeningDelimiters || isWithinClosingDelimiters;

            const isWithinExistingLink = !isWithinDelimiters && lineBeforeWithoutLinks.includes("[[") && lineAfterWithoutLinks.includes("]]");
            const isWithinNewLink = !isWithinDelimiters && lineBeforeWithoutLinks.includes("[[") && !lineAfterWithoutLinks.includes("]]");
            if (!isWithinExistingLink && !isWithinNewLink) return;

            const linkTextBeforeCursor = lineBeforeWithoutLinks.split("[[")[1];
            const linkTextAfterCursor = lineAfterWithoutLinks.split("]]")[0];
            const linkText = linkTextBeforeCursor + linkTextAfterCursor;
            const linkTextUntilWhitespace = linkText.split(" ")[0];

            if (isWithinExistingLink) this.pushEvent("suggest", { term: linkText });
            if (isWithinNewLink) this.pushEvent("suggest", { term: linkTextUntilWhitespace });
        }, { signal });

        // Keydown listener for inserting the first suggestion only when suggestions are active
        this.el.addEventListener("keydown", (e) => {
            if (e.key !== "Enter" && e.key !== "Tab") return;

            const textarea = this.el;
            const value = textarea.value;
            const cursor = textarea.selectionStart;
            const lastIndex = value.lastIndexOf("[[", cursor);
            if (lastIndex === -1) return; // Do not intercept if no open [[

            const suggestionsBox = document.getElementById("suggestions-list");
            const suggestions = Array.from(suggestionsBox.querySelectorAll('li:not(.spacer)')); // Exclude spacer
            if (!suggestions.length) return; // Do not intercept if no suggestions

            e.preventDefault();
            const firstSuggestion = suggestions[0];
            const suggestionText = firstSuggestion.textContent.trim();
            insertSuggestion(this.el, suggestionText);
            this.pushEvent("select_suggestion", {});
        }, { signal });
    },

    updated() {
        // Mark the first suggestion as active whenever suggestions update
        const suggestionsBox = document.getElementById("suggestions-list");
        const suggestions = Array.from(suggestionsBox.querySelectorAll('li:not(.opacity-0)')); // Exclude spacer
        if (!suggestions.length) return;

        suggestions.forEach((item, idx) => {
            if (idx === 0) {
                item.classList.add("active");
                item.dataset.active = "true";
            } else {
                item.classList.remove("active");
                delete item.dataset.active;
            }
        });
    },

    destroyed() { this.abortController.abort() }
};

Hooks.SelectSuggestion = {
    mounted() {
        const targetId = this.el.getAttribute('phx-value-target');
        const suggestion = this.el.getAttribute('phx-value');
        this.abortController = new AbortController();
        const { signal } = this.abortController;

        this.el.addEventListener("mousedown", (e) => {
            e.preventDefault(); // Prevents losing focus on the textarea
            const textarea = document.getElementById(targetId);
            textarea ? insertSuggestion(textarea, suggestion) : console.warn(`Textarea with ID "${targetId}" not found.`);
        }, { signal });
    },

    destroyed() { this.abortController.abort() }
};

function insertSuggestion(textarea, suggestionStr) {
    const suggestion = suggestionStr.trim();
    const cursorPos = textarea.selectionStart;
    const textBeforeCursor = textarea.value.slice(0, cursorPos);
    const match = textBeforeCursor.match(/\[\[([^\]]*)$/);
    if (!match) return;

    const startIndex = match.index;
    const before = textarea.value.slice(0, startIndex);
    const after = textarea.value.slice(cursorPos);
    textarea.value = before + "[[" + suggestion + "]]" + after;
    const newPos = before.length + suggestion.length + 4;
    textarea.setSelectionRange(newPos, newPos);
    textarea.focus();
}

export default Hooks;