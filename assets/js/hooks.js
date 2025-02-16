let Hooks = {};
Hooks.AddKeyboardShortcut = {
    mounted() {
        this.abortController = new AbortController();
        const { signal } = this.abortController;
        const innerHtml = this.el.innerHTML;

        const is_edit_button = this.el.id === "button-edit-page";
        const is_save_button = this.el.id === "button-save-edit";
        const is_cancel_button = this.el.id === "button-cancel-edit";

        // Shortcut for button EDIT  
        if (is_edit_button) {
            document.addEventListener("keydown", (e) => {
                if (e.key === "Control") this.el.innerHTML = "Ctrl + e";
                if (e.ctrlKey && e.key === "e") { e.preventDefault(); this.el.click(); };
            }, { signal });

            document.addEventListener("keyup", (e) => {
                if (e.key === "Control") this.el.innerHTML = innerHtml;
            }, { signal });
        }

        // Shortcuts for buttons SAVE and CANCEL 
        //// We have to attach the event listeners to the textarea
        //// because the textarea captures the keyboad events
        const textarea = document.querySelector("#edit-textarea");
        if (textarea) {
            textarea.addEventListener("keydown", (e) => {
                if (e.key === "Control") {
                    if (is_save_button) this.el.innerHTML = "Ctrl + s";
                    if (is_cancel_button) this.el.innerHTML = "Ctrl + x";
                };
                const is_saving = e.ctrlKey && e.key === "s" && is_save_button;
                const is_cancelling = e.ctrlKey && e.key === "x" && is_cancel_button;
                if (is_saving || is_cancelling) { e.preventDefault(); this.el.click(); };
            }, { signal });
            textarea.addEventListener("keyup", (e) => {
                if (e.key === "Control") this.el.innerHTML = innerHtml;
            }, { signal });
        }
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
            const lastIndex = value.lastIndexOf("[[", cursor);
            if (lastIndex === -1) {
                this.pushEvent("suggest", { term: "" });
                return;
            }

            const termBase = value.substring(lastIndex + 2, cursor);
            const wsIndex = termBase.search(/\s/);
            const term = wsIndex === -1 ? termBase : termBase.substring(0, wsIndex);
            this.pushEvent("suggest", { term });
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