"use strict";

// Progressive enhancement: without JavaScript every figure remains readable.
const tablist = document.querySelector('[role="tablist"]');
const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
const panels = Array.from(document.querySelectorAll('[role="tabpanel"]'));

function selectFigure(tab, moveFocus = false) {
  const target = tab.getAttribute("aria-controls");
  tabs.forEach((item) => {
    const selected = item === tab;
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
  });
  panels.forEach((panel) => { panel.hidden = panel.id !== target; });
  if (moveFocus) tab.focus();
}

if (tablist && tabs.length === panels.length && tabs.length > 0) {
  tablist.hidden = false;
  selectFigure(tabs.find((tab) => tab.getAttribute("aria-selected") === "true") || tabs[0]);
  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectFigure(tab));
    tab.addEventListener("keydown", (event) => {
      let next;
      if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
      else if (event.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length;
      else if (event.key === "Home") next = 0;
      else if (event.key === "End") next = tabs.length - 1;
      else return;
      event.preventDefault();
      selectFigure(tabs[next], true);
    });
  });
}
