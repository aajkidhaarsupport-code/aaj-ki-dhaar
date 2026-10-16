// आज की धार — इंस्टॉल (PWA) सहायक: सर्विस वर्कर, इंस्टॉल बटन/पॉपअप, iPhone गाइड
(function() {
  "use strict";
  var LS_KEY = "aaj_install_dismissed";
  var deferred = null;

  function store(get, v) {
    try { if (get) return localStorage.getItem(LS_KEY); localStorage.setItem(LS_KEY, v); } catch (e) { return null; }
  }
  function isStandalone() {
    return (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches) || window.navigator.standalone === true;
  }
  function recentlyDismissed() {
    var t = parseInt(store(true), 10);
    return t && (Date.now() - t) < 7 * 24 * 3600 * 1000;      // 7 दिन तक दोबारा नहीं दिखाएं
  }

  // सिर्फ़ ज़रूरी टैग यहीं जोड़ दें (अगर index.html में पहले से न हों)
  function ensureTag(tag, attrs) {
    var sel = tag + Object.keys(attrs).filter(function(k) { return k === "rel" || k === "name"; }).map(function(k) { return "[" + k + '="' + attrs[k] + '"]'; }).join("");
    if (document.head.querySelector(sel)) return;
    var el = document.createElement(tag);
    Object.keys(attrs).forEach(function(k) { el.setAttribute(k, attrs[k]); });
    document.head.appendChild(el);
  }
  ensureTag("link", { rel: "manifest", href: "manifest.json" });
  ensureTag("meta", { name: "theme-color", content: "#047857" });
  ensureTag("link", { rel: "apple-touch-icon", href: "apple-touch-icon.png" });
  ensureTag("link", { rel: "icon", type: "image/png", href: "favicon.png" });
  ensureTag("meta", { name: "apple-mobile-web-app-capable", content: "yes" });
  ensureTag("meta", { name: "mobile-web-app-capable", content: "yes" });
  ensureTag("meta", { name: "apple-mobile-web-app-title", content: "आज की धार" });
  ensureTag("meta", { name: "apple-mobile-web-app-status-bar-style", content: "default" });

  if ("serviceWorker" in navigator) {
    window.addEventListener("load", function() {
      navigator.serviceWorker.register("sw.js").catch(function() { /* चुपचाप */ });
    });
  }

  function removeBar() {
    var b = document.getElementById("aaj-install-bar");
    if (b) b.remove();
  }
  function dismiss() { store(false, String(Date.now())); removeBar(); }

  function showBar(ios) {
    if (document.getElementById("aaj-install-bar") || isStandalone() || recentlyDismissed()) return;
    var bar = document.createElement("div");
    bar.id = "aaj-install-bar";
    bar.style.cssText = "position:fixed;left:50%;transform:translateX(-50%);bottom:84px;width:calc(100% - 24px);max-width:420px;z-index:9990;background:#064e3b;color:#fff;border-radius:18px;padding:12px 14px;box-shadow:0 10px 30px rgba(0,0,0,.35);font-family:inherit;display:flex;align-items:center;gap:10px";
    var img = document.createElement("img");
    img.src = "icon-192.png"; img.alt = ""; img.style.cssText = "width:42px;height:42px;border-radius:10px;flex-shrink:0";
    var txt = document.createElement("div");
    txt.style.cssText = "flex:1;font-size:12px;line-height:1.35;font-weight:700";
    txt.textContent = ios ? "ऐप की तरह इस्तेमाल करें: नीचे Share (⬆️) दबाएं → “Add to Home Screen”।" : "“आज की धार” ऐप इंस्टॉल करें — सीधे होम स्क्रीन से ऑर्डर करें।";
    bar.appendChild(img); bar.appendChild(txt);
    if (!ios) {
      var ib = document.createElement("button");
      ib.textContent = "इंस्टॉल";
      ib.style.cssText = "background:#fbbf24;color:#111;border:0;border-radius:12px;padding:8px 12px;font-weight:900;font-size:12px;cursor:pointer";
      ib.onclick = function() {
        if (!deferred) { removeBar(); return; }
        deferred.prompt();
        deferred.userChoice.then(function() { deferred = null; removeBar(); }).catch(function() { removeBar(); });
      };
      bar.appendChild(ib);
    }
    var xb = document.createElement("button");
    xb.textContent = "✕"; xb.setAttribute("aria-label", "बंद करें");
    xb.style.cssText = "background:transparent;color:#a7f3d0;border:0;font-size:16px;cursor:pointer;padding:4px";
    xb.onclick = dismiss;
    bar.appendChild(xb);
    document.body.appendChild(bar);
  }

  window.addEventListener("beforeinstallprompt", function(e) {
    e.preventDefault();                 // Chrome का छोटा बार रोककर अपना बैनर दिखाएंगे
    deferred = e;
    if (document.body) showBar(false); else document.addEventListener("DOMContentLoaded", function() { showBar(false); });
  });
  window.addEventListener("appinstalled", function() { deferred = null; removeBar(); store(false, String(Date.now() + 365 * 24 * 3600 * 1000)); });

  // iPhone/iPad (Safari) में इंस्टॉल प्रॉम्प्ट नहीं होता — सिर्फ़ गाइड दिखाएं
  var ua = navigator.userAgent || "";
  var isIOS = /iphone|ipad|ipod/i.test(ua) && !/crios|fxios|edgios/i.test(ua);
  if (isIOS) {
    window.addEventListener("load", function() { setTimeout(function() { showBar(true); }, 4000); });
  }

  // बाद में कहीं से भी बटन से बुलाने के लिए: installApp()
  window.installApp = function() {
    if (deferred) { deferred.prompt(); return true; }
    if (isIOS) { showBar(true); return true; }
    return false;
  };
})();
