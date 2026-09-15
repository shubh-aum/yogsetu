// YogSetu — shared site behaviour for all inner pages
(function () {
  "use strict";

  // Mobile burger menu
  var burger = document.getElementById("burger");
  var menu = document.getElementById("mobileMenu");
  if (burger && menu) {
    burger.addEventListener("click", function () {
      var open = menu.classList.toggle("open");
      burger.classList.toggle("open", open);
      burger.setAttribute("aria-expanded", open ? "true" : "false");
      burger.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    });
    Array.prototype.forEach.call(menu.querySelectorAll("a"), function (a) {
      a.addEventListener("click", function () {
        menu.classList.remove("open");
        burger.classList.remove("open");
        burger.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Filters panel toggle (teacher / requirement listing pages)
  var filtersToggle = document.querySelector("[data-filters-toggle]");
  var filtersPanel = document.querySelector(".filters-panel");
  if (filtersToggle && filtersPanel) {
    filtersToggle.addEventListener("click", function () {
      filtersPanel.classList.toggle("is-open");
    });
  }

  // Simple tab switcher (used on teacher profile page)
  var tabButtons = document.querySelectorAll("[data-tab-target]");
  if (tabButtons.length) {
    tabButtons.forEach(function (btn) {
      btn.addEventListener("click", function () {
        var group = btn.closest("[data-tab-group]");
        if (!group) return;
        group.querySelectorAll("[data-tab-target]").forEach(function (b) {
          b.classList.remove("active");
        });
        btn.classList.add("active");
        var targetSel = btn.getAttribute("data-tab-target");
        group.querySelectorAll("[data-tab-panel]").forEach(function (p) {
          p.hidden = p.getAttribute("data-tab-panel") !== targetSel;
        });
      });
    });
  }

  // Role toggle on signup page: swap hidden input + adjust copy
  var roleInputs = document.querySelectorAll('input[name="role"]');
  if (roleInputs.length) {
    roleInputs.forEach(function (input) {
      input.addEventListener("change", function () {
        document.querySelectorAll("[data-role-only]").forEach(function (el) {
          el.hidden = el.getAttribute("data-role-only") !== input.value;
        });
      });
    });
    // preselect from ?role= query param
    var params = new URLSearchParams(window.location.search);
    var wanted = params.get("role");
    if (wanted) {
      var match = document.querySelector('input[name="role"][value="' + wanted + '"]');
      if (match) {
        match.checked = true;
        match.dispatchEvent(new Event("change"));
      }
    }
  }

  // Prevent demo forms from navigating away — show a lightweight inline confirmation
  document.querySelectorAll("form[data-demo-form]").forEach(function (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var note = form.querySelector("[data-form-note]");
      if (note) {
        note.hidden = false;
        note.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    });
  });
})();
