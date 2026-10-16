// RunLet editor: CodeMirror 6 with Python. Talks to Swift through window.webkit.messageHandlers.runlet.
import { EditorState, Transaction } from "@codemirror/state";
import { EditorView, keymap, lineNumbers, highlightActiveLine, drawSelection } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, indentWithTab, toggleComment } from "@codemirror/commands";
import { bracketMatching, indentOnInput, syntaxHighlighting, HighlightStyle } from "@codemirror/language";
import { python } from "@codemirror/lang-python";
import { tags as t } from "@lezer/highlight";

const post = (message) => window.webkit?.messageHandlers?.runlet?.postMessage(message);

// Colours come from CSS variables so Swift can switch light and dark without rebuilding the editor.
const highlight = HighlightStyle.define([
  { tag: [t.keyword, t.controlKeyword, t.definitionKeyword, t.moduleKeyword, t.operatorKeyword], color: "var(--syn-keyword)" },
  { tag: [t.string, t.special(t.string)], color: "var(--syn-string)" },
  { tag: [t.number, t.bool, t.null], color: "var(--syn-number)" },
  { tag: [t.comment, t.lineComment], color: "var(--syn-comment)", fontStyle: "italic" },
  { tag: [t.function(t.variableName), t.function(t.propertyName), t.definition(t.variableName)], color: "var(--syn-function)" },
  { tag: [t.className, t.typeName], color: "var(--syn-function)" },
  { tag: [t.operator, t.punctuation], color: "var(--syn-punct)" },
]);

const theme = EditorView.theme({
  "&": { height: "100%", color: "var(--ink)", backgroundColor: "var(--bg)", fontSize: "13px" },
  ".cm-scroller": { fontFamily: "var(--mono)", lineHeight: "1.6", overflow: "auto" },
  ".cm-content": { caretColor: "var(--accent)", padding: "10px 0" },
  ".cm-cursor": { borderLeftColor: "var(--accent)", borderLeftWidth: "2px" },
  "&.cm-focused": { outline: "none" },
  ".cm-gutters": { backgroundColor: "var(--bg)", color: "var(--muted)", border: "none" },
  ".cm-lineNumbers .cm-gutterElement": { padding: "0 10px 0 14px" },
  ".cm-activeLine": { backgroundColor: "var(--active-line)" },
  ".cm-activeLineGutter": { backgroundColor: "transparent", color: "var(--ink)" },
  ".cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection": { backgroundColor: "var(--selection)" },
  "&.cm-focused .cm-matchingBracket": { backgroundColor: "var(--selection)", outline: "none" },
});

let applyingFromSwift = false;

// Paste goes to Swift to be cleaned. The original text goes in first and the cleaned text replaces it as a
// separate undo step, so one undo shows exactly what was pasted.
function applyPaste(view, raw, reply) {
  const { from, to } = view.state.selection.main;
  view.dispatch({ changes: { from, to, insert: raw }, selection: { anchor: from + raw.length }, userEvent: "input.paste", scrollIntoView: true });
  if (reply && typeof reply.text === "string" && reply.text !== raw) {
    view.dispatch({
      changes: { from, to: from + raw.length, insert: reply.text }, selection: { anchor: from + reply.text.length },
      annotations: Transaction.isolateHistory.of("full"), userEvent: "input.paste", scrollIntoView: true,
    });
    post({ type: "pasted", notice: reply.notice ?? null });
  }
}

const cleanOnPaste = EditorView.domEventHandlers({
  paste(event, view) {
    const raw = event.clipboardData?.getData("text/plain");
    const handler = window.webkit?.messageHandlers?.paste;
    if (!raw || !handler) return false;
    event.preventDefault();
    handler.postMessage(raw).then((reply) => applyPaste(view, raw, reply), () => applyPaste(view, raw, null));
    return true;
  },
});

const view = new EditorView({
  parent: document.getElementById("editor"),
  state: EditorState.create({
    doc: "",
    extensions: [
      lineNumbers(), history(), drawSelection(), highlightActiveLine(), indentOnInput(), bracketMatching(),
      python(), syntaxHighlighting(highlight), theme, cleanOnPaste,
      keymap.of([{ key: "Mod-/", run: toggleComment }, indentWithTab, ...defaultKeymap, ...historyKeymap]),
      EditorView.updateListener.of((update) => {
        if (update.docChanged && !applyingFromSwift) post({ type: "change", text: update.state.doc.toString() });
      }),
    ],
  }),
});

// A fade on an edge that has hidden content.
const root = document.getElementById("editor");
const scroller = view.scrollDOM;
const updateEdges = () => {
  root.classList.toggle("fade-top", scroller.scrollTop > 4);
  root.classList.toggle("fade-bottom", scroller.scrollHeight - scroller.clientHeight - scroller.scrollTop > 4);
};
scroller.addEventListener("scroll", updateEdges, { passive: true });
new ResizeObserver(updateEdges).observe(scroller);
new MutationObserver(updateEdges).observe(view.contentDOM, { childList: true, subtree: true });

window.RunLetEditor = {
  setText(text) {
    applyingFromSwift = true;
    view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text }, selection: { anchor: 0 } });
    applyingFromSwift = false;
  },
  getText: () => view.state.doc.toString(),
  setTheme(colors) {
    const root = document.documentElement;
    root.dataset.dark = colors.dark ? "1" : "0";
    for (const [name, value] of Object.entries(colors.vars)) root.style.setProperty(`--${name}`, value);
  },
  focus: () => view.focus(),
};

post({ type: "ready" });
