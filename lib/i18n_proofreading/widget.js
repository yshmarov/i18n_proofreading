/*
 * i18n_proofreading widget — self-contained, no framework, no build step.
 *
 * Reads its config from the <script type="application/json"
 * data-i18n-proofreading-config> the server injects — re-read on every render so a
 * Turbo visit always reflects the current page's suggest state.
 *
 * A floating pill toggles "suggest mode", which is server state: the pill sets or
 * clears the i18n_proofreading cookie and reloads, so the backend only prints the
 * "…text… ⟦some.key.path⟧" markers while proofreading. The markers are never shown
 * to the user — on load the widget strips each ⟦key⟧ token out of the DOM and
 * stashes the key on its element. A click on any such element opens a popover to
 * suggest a wording; navigation is frozen while the popover is open. Esc, or the
 * pill, exits.
 */
(function () {
  "use strict";

  var config = readConfig();
  if (!config || window.__i18nProofreadingLoaded) return;
  window.__i18nProofreadingLoaded = true;

  var LEFT = "⟦"; // ⟦
  var RIGHT = "⟧"; // ⟧
  var TOKEN = new RegExp(LEFT + "([^" + RIGHT + "]+)" + RIGHT);
  var TOKENS = new RegExp("\\s*" + LEFT + "[^" + RIGHT + "]+" + RIGHT, "g");
  var COOKIE = "i18n_proofreading";
  var MARKED_ATTRS = ["placeholder", "title", "aria-label", "value"];
  var Z = 2147483000;

  var overlay = null;
  var proposedInput = null;
  var commentInput = null;
  var errorNode = null;
  var saveButton = null;
  var priorNode = null;

  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  ready(function () {
    // Document-level listeners survive Turbo navigations, so register them once.
    // handleClick is always attached and gates on the *current* config.active, so
    // toggling suggest mode across a Turbo visit needs no re-registration.
    document.addEventListener("keydown", handleKeydown);
    document.addEventListener("click", handleClick, true);

    // Everything else lives in <body>, which Turbo replaces on every visit —
    // taking the pill and the active-mode highlighting with it. Re-run the
    // per-page setup on each visit so the widget keeps working without a hard
    // reload. render() also runs now for the initial (or non-Turbo) load.
    render();
    document.addEventListener("turbo:load", render);
    document.addEventListener("turbo:frame-load", strip);
  });

  function readConfig() {
    var el = document.querySelector("script[data-i18n-proofreading-config]");
    if (!el) return null;
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return null;
    }
  }

  function render() {
    // Re-read on each visit: the injected config is data (not an executed
    // script), so it reflects the page Turbo just rendered.
    config = readConfig() || config;
    injectStyles();
    if (config.showPill !== false) buildPill();
    document.documentElement.classList.toggle("i18np-active", !!config.active);
    if (config.active) strip();
  }

  // --- suggest-mode toggle --------------------------------------------------

  function toggle() {
    if (config.active) {
      document.cookie = COOKIE + "=; path=/; max-age=0";
    } else {
      document.cookie = COOKIE + "=1; path=/";
    }
    window.location.reload();
  }

  // --- marker stripping -----------------------------------------------------

  function strip() {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        var tag = node.parentElement && node.parentElement.tagName;
        if (tag === "SCRIPT" || tag === "STYLE") return NodeFilter.FILTER_REJECT;
        return TOKEN.test(node.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      },
    });

    var nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach(function (node) {
      var match = node.nodeValue.match(TOKEN);
      if (!match) return;
      var key = match[1];
      node.nodeValue = node.nodeValue.replace(TOKENS, "");
      var element = node.parentElement;
      if (element) {
        element.dataset.i18nKey = key;
        element.dataset.i18nValue = node.nodeValue.trim();
      }
    });

    MARKED_ATTRS.forEach(function (attr) {
      var selector = "[" + attr + '*="' + LEFT + '"]';
      document.querySelectorAll(selector).forEach(function (element) {
        element.setAttribute(attr, element.getAttribute(attr).replace(TOKENS, ""));
      });
    });
  }

  // --- interaction ----------------------------------------------------------

  function handleClick(event) {
    if (!config.active) return;
    if (overlay && overlay.contains(event.target)) return;
    if (event.target.closest && event.target.closest(".i18np-pill")) return;
    // Let a host's own suggest-mode toggle link through (e.g. "?i18n_proofreading=false"
    // in a nav menu); otherwise navigation-freezing would trap the user in suggest
    // mode with no way out but the pill.
    if (event.target.closest && event.target.closest('a[href*="' + config.toggleParam + '="]')) return;

    // Freeze navigation so a stray click can't leave the page mid-proofread.
    event.preventDefault();
    event.stopPropagation();

    var element = event.target.closest && event.target.closest("[data-i18n-key]");
    if (element) open(element.dataset.i18nKey, element.dataset.i18nValue || "");
  }

  function handleKeydown(event) {
    if (event.key !== "Escape") return;
    if (overlay) close();
    else if (config.active) toggle();
  }

  // --- pill -----------------------------------------------------------------

  function buildPill() {
    var existing = document.querySelector(".i18np-pill");
    if (existing) existing.remove();

    var pill = document.createElement("button");
    pill.type = "button";
    pill.className = "i18np-pill" + (config.active ? " i18np-pill-on" : "");
    pill.textContent = config.active ? "✓ " + t("pillActive", "Suggesting — tap to exit (Esc)") : "✎ " + labelText();
    pill.addEventListener("click", toggle);
    document.body.appendChild(pill);
  }

  function labelText() {
    return config.pillLabel || t("pill", "Suggest edits");
  }

  // Resolve a server-translated label, falling back to English if the config
  // predates the labels payload (e.g. a cached page from an older gem version).
  function t(name, fallback) {
    return (config.labels && config.labels[name]) || fallback;
  }

  // --- popover --------------------------------------------------------------

  function open(key, currentValue) {
    close();

    overlay = el("div", "i18np-overlay");
    overlay.addEventListener("click", function (event) {
      if (event.target === overlay) close();
    });

    var panel = el("div", "i18np-panel");
    // Mirror the popover for right-to-left locales (Arabic, Urdu, …). The i18n
    // key stays LTR — it's a code identifier, not prose (see heading()).
    panel.dir = config.rtl ? "rtl" : "ltr";
    panel.appendChild(heading(key));

    priorNode = el("div");
    panel.appendChild(priorNode);

    panel.appendChild(field(t("currentText", "Current text"), readonly(currentValue)));

    proposedInput = textarea(currentValue);
    panel.appendChild(field(t("suggestedText", "Suggested text"), proposedInput));

    commentInput = input(t("commentPlaceholder", "Optional note for the developer"));
    panel.appendChild(field(t("comment", "Comment"), commentInput));

    errorNode = el("p", "i18np-error");
    errorNode.style.display = "none";
    panel.appendChild(errorNode);

    panel.appendChild(actions(key, currentValue));

    overlay.appendChild(panel);
    document.body.appendChild(overlay);
    proposedInput.focus();
    loadPrior(key);
  }

  function close() {
    if (overlay) {
      overlay.remove();
      overlay = null;
    }
  }

  function loadPrior(key) {
    var params = new URLSearchParams({ key: key, locale: config.locale });
    fetch(config.endpoint + "/context?" + params.toString(), { headers: { Accept: "application/json" } })
      .then(function (response) {
        return response.ok ? response.json() : [];
      })
      .then(function (items) {
        if (items && items.length) renderPrior(items);
      })
      .catch(function () {
        // Best-effort context; ignore fetch/parse errors.
      });
  }

  function renderPrior(items) {
    if (!priorNode) return;

    var box = el("div", "i18np-prior");
    var title = el("p", "i18np-prior-title");
    title.textContent = t("priorTitle", "Already suggested (pending)");
    box.appendChild(title);

    var list = el("ul", "i18np-prior-list");
    items.forEach(function (item) {
      var row = document.createElement("li");
      var who = item.author_label ? " — " + item.author_label : "";
      row.textContent = "“" + item.proposed_value + "”" + who;
      list.appendChild(row);
    });
    box.appendChild(list);

    priorNode.replaceWith(box);
    priorNode = box;
  }

  function actions(key, currentValue) {
    var wrapper = el("div", "i18np-actions");

    var cancel = el("button", "i18np-btn i18np-btn-ghost");
    cancel.type = "button";
    cancel.textContent = t("cancel", "Cancel");
    cancel.addEventListener("click", close);

    saveButton = el("button", "i18np-btn i18np-btn-primary");
    saveButton.type = "button";
    saveButton.textContent = t("save", "Send suggestion");
    saveButton.addEventListener("click", function () {
      submit(key, currentValue);
    });

    wrapper.appendChild(cancel);
    wrapper.appendChild(saveButton);
    return wrapper;
  }

  function submit(key, currentValue) {
    var proposed = proposedInput.value.trim();
    if (!proposed) {
      showError(t("errorBlank", "Please enter a suggestion."));
      return;
    }

    saveButton.disabled = true;

    fetch(config.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        suggestion: {
          translation_key: key,
          locale: config.locale,
          old_value: currentValue,
          proposed_value: proposed,
          comment: commentInput.value.trim(),
          page_url: window.location.href,
        },
      }),
    })
      .then(function (response) {
        if (response.ok) {
          close();
        } else {
          saveButton.disabled = false;
          showError(t("errorSave", "Could not save the suggestion."));
        }
      })
      .catch(function () {
        saveButton.disabled = false;
        showError("Could not save the suggestion.");
      });
  }

  function showError(message) {
    errorNode.textContent = message;
    errorNode.style.display = "";
  }

  // --- small DOM builders ---------------------------------------------------

  function heading(key) {
    var wrapper = el("div", "i18np-heading");
    var title = el("p", "i18np-title");
    title.textContent = t("title", "Suggest a translation fix");
    var code = el("code", "i18np-key");
    code.dir = "ltr"; // the key is a code path, never RTL prose
    code.textContent = key;
    wrapper.appendChild(title);
    wrapper.appendChild(code);
    return wrapper;
  }

  function field(label, control) {
    var wrapper = el("label", "i18np-field");
    var text = el("span", "i18np-label");
    text.textContent = label;
    wrapper.appendChild(text);
    wrapper.appendChild(control);
    return wrapper;
  }

  function readonly(value) {
    var node = el("p", "i18np-readonly");
    node.textContent = value;
    return node;
  }

  function textarea(value) {
    var node = el("textarea", "i18np-input");
    node.rows = 3;
    node.value = value;
    return node;
  }

  function input(placeholder) {
    var node = el("input", "i18np-input");
    node.type = "text";
    node.placeholder = placeholder;
    return node;
  }

  function el(tag, className) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    return node;
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  // --- styles ---------------------------------------------------------------

  function injectStyles() {
    if (document.getElementById("i18np-styles")) return;
    var style = document.createElement("style");
    style.id = "i18np-styles";
    style.textContent = [
      // Only the strings that actually resolve to a key are editable, so only
      // those are highlighted. `outline` (not `border`) avoids any layout shift.
      ".i18np-active [data-i18n-key] { cursor: copy; outline: 1px dashed rgba(37, 99, 235, 0.5); outline-offset: 2px; }",
      ".i18np-active [data-i18n-key]:hover { outline: 2px dashed #2563eb; outline-offset: 2px; background: rgba(37, 99, 235, 0.08); }",
      ".i18np-pill { position: fixed; bottom: 16px; left: 16px; z-index: " + (Z + 1) + ";",
      "  font: 13px/1.2 system-ui, sans-serif; padding: 9px 14px; border-radius: 999px;",
      "  border: 1px solid rgba(0,0,0,.15); background: #fff; color: #111; cursor: pointer;",
      "  box-shadow: 0 4px 14px rgba(0,0,0,.18); }",
      ".i18np-pill-on { background: #2563eb; color: #fff; border-color: #2563eb; }",
      ".i18np-overlay { position: fixed; inset: 0; z-index: " + (Z + 2) + "; display: flex;",
      "  align-items: center; justify-content: center; padding: 16px;",
      "  background: rgba(0,0,0,.45); cursor: default; }",
      ".i18np-panel { width: 28rem; max-width: 100%; max-height: 90vh; overflow: auto;",
      "  overscroll-behavior: contain;",
      "  background: #fff; color: #111; border-radius: 12px; padding: 20px;",
      "  box-shadow: 0 20px 60px rgba(0,0,0,.35); font: 14px/1.5 system-ui, sans-serif; }",
      ".i18np-panel > * + * { margin-top: 14px; }",
      ".i18np-title { font-weight: 700; font-size: 15px; margin: 0; }",
      ".i18np-key { display: block; margin-top: 2px; font-size: 12px; color: #666;",
      "  word-break: break-all; font-family: ui-monospace, monospace; }",
      ".i18np-field { display: block; }",
      ".i18np-label { display: block; margin-bottom: 4px; font-size: 12px; color: #666; }",
      ".i18np-readonly { margin: 0; padding: 8px 10px; background: #f4f4f5; border-radius: 8px; }",
      ".i18np-input { display: block; width: 100%; box-sizing: border-box; padding: 8px 10px;",
      "  border: 1px solid #d4d4d8; border-radius: 8px; font: inherit; }",
      ".i18np-prior { padding: 10px 12px; background: #f4f4f5; border-radius: 8px; font-size: 13px; }",
      ".i18np-prior-title { margin: 0 0 4px; font-weight: 600; color: #555; }",
      ".i18np-prior-list { margin: 0; padding-left: 18px; }",
      ".i18np-error { margin: 0; color: #dc2626; font-size: 13px; }",
      ".i18np-actions { display: flex; justify-content: flex-end; gap: 8px; }",
      ".i18np-btn { padding: 8px 14px; border-radius: 8px; border: 1px solid transparent;",
      "  font: inherit; cursor: pointer; }",
      ".i18np-btn-ghost { background: transparent; color: #111; }",
      ".i18np-btn-primary { background: #2563eb; color: #fff; }",
      ".i18np-btn[disabled] { opacity: .6; cursor: default; }",

      // Follow the OS light/dark/system setting via prefers-color-scheme, so the
      // widget matches whatever the reviewer's system is set to without any extra
      // configuration. Only the surfaces that carry their own background/color
      // above are overridden here — the blue accents stay the same in both themes.
      "@media (prefers-color-scheme: dark) {",
      "  .i18np-pill { background: #1f1f23; color: #f4f4f5; border-color: rgba(255,255,255,.18);",
      "    box-shadow: 0 4px 14px rgba(0,0,0,.5); }",
      "  .i18np-pill-on { background: #2563eb; color: #fff; border-color: #2563eb; }",
      "  .i18np-overlay { background: rgba(0,0,0,.65); }",
      "  .i18np-panel { background: #1f1f23; color: #f4f4f5;",
      "    box-shadow: 0 20px 60px rgba(0,0,0,.7); }",
      "  .i18np-key { color: #a1a1aa; }",
      "  .i18np-label { color: #a1a1aa; }",
      "  .i18np-readonly { background: #2a2a30; }",
      "  .i18np-input { background: #2a2a30; color: #f4f4f5; border-color: #3f3f46; }",
      "  .i18np-input::placeholder { color: #71717a; }",
      "  .i18np-prior { background: #2a2a30; }",
      "  .i18np-prior-title { color: #d4d4d8; }",
      "  .i18np-error { color: #f87171; }",
      "  .i18np-btn-ghost { color: #f4f4f5; }",
      "}",

      // Full-screen popover on small screens — no bottom sheet, no animation.
      // Selectors are at least as specific as the base rules and this block
      // comes last, so the mobile values win.
      "@media (max-width: 480px) {",
      "  .i18np-overlay { padding: 0; }",
      "  .i18np-overlay .i18np-panel { position: fixed; top: 0; right: 0; bottom: 0; left: 0;",
      "    width: 100%; height: 100dvh; max-height: 100dvh; border-radius: 0; margin: 0; }",
      // 16px inputs stop iOS Safari from zooming the page on focus.
      "  .i18np-panel input.i18np-input, .i18np-panel textarea.i18np-input,",
      "  .i18np-panel select { font-size: 16px; }",
      // Keep the action row clear of the iPhone home indicator (its own
      // padding-bottom is 0; the panel padding sits outside the row).
      "  .i18np-panel .i18np-actions { padding-bottom: calc(0px + env(safe-area-inset-bottom)); }",
      "}",
    ].join("\n");
    document.head.appendChild(style);
  }
})();
