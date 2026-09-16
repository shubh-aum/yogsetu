// YogSetu — shared dashboard shell behaviour
(function () {
  "use strict";

  // Sidebar section switching
  var navItems = document.querySelectorAll(".dash-nav-item[data-section]");
  var sections = document.querySelectorAll(".dash-section[data-section-panel]");
  var titleEl = document.getElementById("dashTitle");
  var subEl = document.getElementById("dashSub");

  function activate(key) {
    navItems.forEach(function (b) {
      b.classList.toggle("active", b.getAttribute("data-section") === key);
    });
    sections.forEach(function (s) {
      s.classList.toggle("active", s.getAttribute("data-section-panel") === key);
    });
    var btn = document.querySelector('.dash-nav-item[data-section="' + key + '"]');
    if (btn) {
      if (titleEl) titleEl.textContent = btn.getAttribute("data-title") || btn.textContent.trim();
      if (subEl) subEl.textContent = btn.getAttribute("data-sub") || "";
    }
    var sidebar = document.querySelector(".dash-sidebar");
    if (sidebar) sidebar.classList.remove("open");
    window.scrollTo({ top: 0, behavior: "instant" in window ? "instant" : "auto" });
  }

  navItems.forEach(function (btn) {
    btn.addEventListener("click", function () {
      activate(btn.getAttribute("data-section"));
    });
  });

  if (navItems.length) {
    var initial = window.location.hash ? window.location.hash.slice(1) : null;
    var match = initial && document.querySelector('.dash-nav-item[data-section="' + initial + '"]');
    activate(match ? initial : navItems[0].getAttribute("data-section"));
  }

  // "View all" style buttons that jump to another sidebar section
  document.querySelectorAll("[data-section-jump]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      activate(btn.getAttribute("data-section-jump"));
    });
  });

  // Mobile sidebar toggle
  var dashBurger = document.getElementById("dashBurger");
  var sidebar = document.querySelector(".dash-sidebar");
  if (dashBurger && sidebar) {
    dashBurger.addEventListener("click", function () {
      sidebar.classList.toggle("open");
    });
  }

  // Generic modal open/close: [data-modal-open="id"] / [data-modal-close]
  document.querySelectorAll("[data-modal-open]").forEach(function (trigger) {
    trigger.addEventListener("click", function () {
      var id = trigger.getAttribute("data-modal-open");
      var modal = document.getElementById(id);
      if (modal) modal.classList.add("open");
    });
  });
  document.querySelectorAll("[data-modal-close]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      btn.closest(".modal-backdrop").classList.remove("open");
    });
  });
  document.querySelectorAll(".modal-backdrop").forEach(function (backdrop) {
    backdrop.addEventListener("click", function (e) {
      if (e.target === backdrop) backdrop.classList.remove("open");
    });
  });

  // Star rating input
  document.querySelectorAll(".star-input").forEach(function (group) {
    var stars = group.querySelectorAll("span");
    stars.forEach(function (star, idx) {
      star.addEventListener("click", function () {
        stars.forEach(function (s, i) { s.classList.toggle("on", i <= idx); });
        group.setAttribute("data-value", idx + 1);
      });
    });
  });

  // Demo action buttons: accept/decline/approve/reject/toggle just flip a status pill in place
  document.querySelectorAll("[data-demo-action]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var row = btn.closest("[data-row]");
      if (!row) return;
      var pill = row.querySelector(".status-pill");
      var action = btn.getAttribute("data-demo-action");
      var map = {
        accept: "approved", approve: "approved", decline: "declined",
        reject: "rejected", disable: "disabled", enable: "active"
      };
      if (pill && map[action]) {
        pill.className = "status-pill " + map[action];
        pill.textContent = map[action].charAt(0).toUpperCase() + map[action].slice(1);
      }
      row.style.opacity = "0.55";
      var actions = row.querySelector(".row-actions, .actions");
      if (actions) actions.innerHTML = '<span style="font-size:12px;color:var(--ink-faint);">Updated</span>';
    });
  });

  // Demo forms (profile save, pricing save, etc.) — inline confirmation, no navigation
  document.querySelectorAll("form[data-demo-form]").forEach(function (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var note = form.querySelector("[data-form-note]");
      if (note) {
        note.hidden = false;
        setTimeout(function () { note.hidden = true; }, 3000);
      }
    });
  });

  // Toggle switches with a demo label next to them
  document.querySelectorAll(".tswitch input[data-demo-toggle]").forEach(function (input) {
    input.addEventListener("change", function () {
      var label = input.closest(".tswitch").querySelector(".lbl");
      if (!label) return;
      var onText = input.getAttribute("data-on") || "On";
      var offText = input.getAttribute("data-off") || "Off";
      label.textContent = input.checked ? onText : offText;
    });
  });
})();
