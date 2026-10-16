// आज की धार — सर्विस वर्कर
// नियम: पेज हमेशा पहले नेटवर्क से (ताज़ा संस्करण); नेट न हो तो पिछला सेव किया पेज।
// Supabase / लॉगिन / ऑर्डर के अनुरोध कभी कैश नहीं होते।
var VERSION = "aajkidhar-v5";
var CORE = ["./", "index.html", "manifest.json", "icon-192.png", "icon-512.png", "apple-touch-icon.png"];

self.addEventListener("install", function(e) {
  e.waitUntil(caches.open(VERSION).then(function(c) {
    return Promise.all(CORE.map(function(u) { return c.add(u).catch(function() {}); }));
  }).then(function() { return self.skipWaiting(); }));
});

self.addEventListener("activate", function(e) {
  e.waitUntil(caches.keys().then(function(keys) {
    return Promise.all(keys.filter(function(k) { return k !== VERSION; }).map(function(k) { return caches.delete(k); }));
  }).then(function() { return self.clients.claim(); }));
});

self.addEventListener("fetch", function(e) {
  var req = e.request;
  if (req.method !== "GET") return;
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;           // बाहरी (Supabase, CDN) को छुएं नहीं
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then(function(res) {
      var copy = res.clone();
      caches.open(VERSION).then(function(c) { c.put("index.html", copy); });
      return res;
    }).catch(function() {
      return caches.match("index.html").then(function(r) { return r || caches.match("./"); });
    }));
    return;
  }
  if (/\.(js|json|html)$/.test(url.pathname)) {            // config.js, pwa.js आदि: पहले नेटवर्क (ताज़ा), नेट न हो तो कैश
    e.respondWith(fetch(req).then(function(res) {
      if (res && res.status === 200) { var copy = res.clone(); caches.open(VERSION).then(function(c) { c.put(req, copy); }); }
      return res;
    }).catch(function() { return caches.match(req); }));
    return;
  }
  e.respondWith(caches.match(req).then(function(hit) {       // आइकन वगैरह: पहले कैश
    return hit || fetch(req).then(function(res) {
      if (res && res.status === 200) { var copy = res.clone(); caches.open(VERSION).then(function(c) { c.put(req, copy); }); }
      return res;
    });
  }));
});
