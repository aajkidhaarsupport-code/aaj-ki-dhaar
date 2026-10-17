// आज की धार — भाषा बदलने का इंजन (हिंदी / English / मराठी)
// ऐप का मूल पाठ हिंदी में है। यह फ़ाइल हर दिखने वाले पाठ को चुनी हुई भाषा में बदल देती है।
// नई भाषा जोड़नी हो तो LANGS में एक पंक्ति और DATA की हर पंक्ति में एक अनुवाद जोड़ें।
(function() {
  "use strict";
  var LANGS = [
    { c: "hi", n: "हिंदी", loc: "hi-IN" },
    { c: "en", n: "English", loc: "en-IN" },
    { c: "mr", n: "मराठी", loc: "mr-IN" }
  ];
  var IDX = { hi: 0, en: 1, mr: 2 };   // DATA की पंक्ति में भाषा का स्थान
  var lang = "hi";
  var DATA = [];        // [hi, en, mr]
  var HTMLD = {};       // data-i18n-html के लिए: { key: { en: "...", mr: "..." } }
  var POL = {};         // पॉलिसी: { refund: { en: {title, body}, mr: {...} } }
  var exact = {}, pats = [], ready = false;

  var norm = function(s) { return String(s).replace(/\s+/g, " ").trim(); };
  var escRe = function(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); };

  function build() {
    exact = {}; pats = [];
    DATA.forEach(function(row) {
      var hi = norm(row[0]);
      if (/\{\d\}/.test(hi)) {
        var parts = hi.split(/\{(\d)\}/), re = "^", idxs = [], lit = 0;
        for (var i = 0; i < parts.length; i++) {
          if (i % 2 === 0) { re += escRe(parts[i]); lit += parts[i].length; }
          else { re += "([\\s\\S]*?)"; idxs.push(parts[i]); }
        }
        pats.push({ re: new RegExp(re + "$"), idxs: idxs, row: row, lit: lit });
      } else {
        exact[hi] = row;
      }
    });
    pats.sort(function(a, b) { return b.lit - a.lit; });
    ready = true;
  }

  function trCore(core, depth) {
    if (lang === "hi" || !core) return core;
    var k = IDX[lang];
    var n = norm(core);
    var hit = exact[n];
    if (hit && hit[k]) return hit[k];
    for (var i = 0; i < pats.length; i++) {
      var p = pats[i], m = p.re.exec(n);
      if (m && p.row[k]) {
        var out = p.row[k];
        for (var g = 0; g < p.idxs.length; g++) {
          var cap = m[g + 1];
          var t = (depth > 2) ? cap : trCap(cap, depth + 1);
          out = out.split("{" + p.idxs[g] + "}").join(t);
        }
        return out;
      }
    }
    return core;
  }
  // कैप्चर किया हुआ हिस्सा (नाम, सूची आदि) भी अनुवादित हो
  function trCap(c, depth) {
    var t = trCore(c, depth);
    if (t !== c) return t;
    if (c.indexOf(", ") > -1) return c.split(", ").map(function(x) { return trCore(x, depth); }).join(", ");
    return c;
  }
  function tr(str) {
    if (lang === "hi" || str == null || str === "") return str;
    str = String(str);
    var m = /^(\s*)([\s\S]*?)(\s*)$/.exec(str);
    return m[1] + trCore(m[2], 0) + m[3];
  }
  // बॉट के HTML उत्तर: टैग हटाकर मिलान, मिलने पर पूरा अनुवादित HTML
  function trHtml(html) {
    if (lang === "hi") return html;
    var toks = [];
    var h = String(html).replace(/<(a|button)\b[\s\S]*?<\/\1>/g, function(m) { toks.push(m); return "{A" + (toks.length - 1) + "}"; });
    var plain = norm(h.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, ""));
    var out = trCore(plain, 0);
    if (out === plain) return html;
    return out.replace(/\{A(\d)\}/g, function(_, i) { return toks[+i] || ""; });
  }

  // ---------------- DOM ----------------
  var ORIG = new WeakMap(), LAST = new WeakMap(), AORIG = new WeakMap(), HORIG = new WeakMap();
  var ATTRS = ["placeholder", "title", "alt"];
  var origTitle = null;

  function skipEl(el) {
    return !!(el.closest && el.closest("[data-notr],#admin-dashboard-modal,#admin-pin-modal,script,style"));
  }
  function textNode(n) {
    var cur = n.nodeValue, last = LAST.get(n), orig = ORIG.get(n);
    if (orig === undefined || (last !== undefined && cur !== last)) { orig = cur; ORIG.set(n, orig); }
    var out = lang === "hi" ? orig : tr(orig);
    if (out !== cur) n.nodeValue = out;
    LAST.set(n, out);
  }
  function attrsOf(el) {
    ATTRS.forEach(function(a) {
      if (!el.hasAttribute(a)) return;
      var store = AORIG.get(el); if (!store) { store = {}; AORIG.set(el, store); }
      var cur = el.getAttribute(a);
      if (store[a] === undefined || (store[a].last !== undefined && store[a].last !== cur)) store[a] = { orig: cur };
      var out = lang === "hi" ? store[a].orig : tr(store[a].orig);
      store[a].last = out;
      if (out !== cur) el.setAttribute(a, out);
    });
  }
  function htmlEl(el) {
    var key = el.getAttribute("data-i18n-html");
    if (!HORIG.has(el)) HORIG.set(el, el.innerHTML);
    var d = HTMLD[key];
    el.innerHTML = (lang !== "hi" && d && d[lang]) ? d[lang] : HORIG.get(el);
  }
  function walk(node) {
    if (node.nodeType === 3) { textNode(node); return; }
    if (node.nodeType !== 1) return;
    if (node.hasAttribute("data-notr") || node.id === "admin-dashboard-modal" || node.id === "admin-pin-modal") return;
    var tag = node.tagName;
    if (tag === "SCRIPT" || tag === "STYLE") return;
    attrsOf(node);
    if (node.hasAttribute("data-i18n-html")) { htmlEl(node); return; }
    for (var c = node.firstChild; c; c = c.nextSibling) walk(c);
  }

  var obs = null;
  function observe() {
    if (!obs) return;
    obs.observe(document.body, { childList: true, subtree: true, characterData: true });
  }
  function onMutations(muts) {
    if (lang === "hi") return;
    obs.disconnect();
    try {
      muts.forEach(function(m) {
        if (m.type === "characterData") {
          var p = m.target.parentElement;
          if (p && !skipEl(p)) textNode(m.target);
        } else {
          m.addedNodes.forEach(function(n) {
            var el = n.nodeType === 1 ? n : n.parentElement;
            if (el && !skipEl(el)) walk(n);
          });
        }
      });
    } finally { observe(); }
  }

  function applyAll() {
    if (!document.body) return;
    if (obs) obs.disconnect();
    document.documentElement.lang = lang;
    if (origTitle === null) origTitle = document.title;
    document.title = lang === "hi" ? origTitle : tr(origTitle);
    walk(document.body);
    observe();
  }

  window.I18N = {
    langs: LANGS,
    get lang() { return lang; },
    locale: function() { for (var i = 0; i < LANGS.length; i++) if (LANGS[i].c === lang) return LANGS[i].loc; return "hi-IN"; },
    init: function() {
      if (!ready) build();
      var saved = "hi";
      try { saved = localStorage.getItem("aaj_lang") || "hi"; } catch (e) { /* ignore */ }
      lang = IDX[saved] !== undefined ? saved : "hi";
      obs = new MutationObserver(onMutations);
      applyAll();
    },
    set: function(code) {
      if (IDX[code] === undefined) return;
      lang = code;
      try { localStorage.setItem("aaj_lang", code); } catch (e) { /* ignore */ }
    },
    apply: applyAll,
    tr: tr,
    trHtml: trHtml,
    policy: function(key) {
      if (lang === "hi") return null;
      var p = POL[key];
      return (p && p[lang]) ? p[lang] : null;
    },
    _add: function(rows) { DATA = DATA.concat(rows); ready = false; },
    _html: function(o) { for (var k in o) HTMLD[k] = o[k]; },
    _pol: function(o) { for (var k in o) POL[k] = o[k]; }
  };
  // ऐप में कहीं भी: window.t("हिंदी पाठ") → चुनी हुई भाषा में
  window.t = function(s) { return window.I18N.tr(s); };
})();
window.I18N._add([
// ---- होम / हेडर / कट-ऑफ ----
["डिलीवरी कट-ऑफ (रात 10 बजे):","Delivery cut-off (10 PM):","डिलिव्हरी कट-ऑफ (रात्री 10 वाजता):"],
["ऑर्डर बंद • फिर शुरू होने में:","Orders closed • reopens in:","ऑर्डर बंद • पुन्हा सुरू होण्यास:"],
["रात 10 बजे के बाद ऑर्डर बंद हैं। रात 12 बजे के बाद फिर से ऑर्डर कर सकेंगे।","Orders are closed after 10 PM. You can order again after 12 midnight.","रात्री 10 नंतर ऑर्डर बंद असतात. रात्री 12 नंतर पुन्हा ऑर्डर करता येतील."],
["⏰ रात 10 बजे के बाद ऑर्डर बंद हैं। रात 12 बजे के बाद फिर से ऑर्डर कर सकेंगे।","⏰ Orders are closed after 10 PM. You can order again after 12 midnight.","⏰ रात्री 10 नंतर ऑर्डर बंद असतात. रात्री 12 नंतर पुन्हा ऑर्डर करता येतील."],
["आज की धार","Aaj Ki Dhar","आज की धार"],
["आज की धार (Aaj Ki Dhar)","Aaj Ki Dhar","आज की धार (Aaj Ki Dhar)"],
["जयपुर फार्म","Jaipur Farm","जयपूर फार्म"],
["लॉगिन / साइन अप करें","Log in / Sign up","लॉग इन / साइन अप करा"],
["पता जोड़ें","Add address","पत्ता जोडा"],
["अतिथि","Guest","पाहुणे"],
["वॉलेट","Wallet","वॉलेट"],
["डिलीवरी रुकी हुई है (छुट्टी चालू)","Delivery is paused (holiday on)","डिलिव्हरी थांबवली आहे (सुट्टी सुरू)"],
["जल्दी शुरू करें","Resume early","लवकर सुरू करा"],
["आज सुबह की लाइव धार स्थिति","Today morning's live status","आज सकाळची थेट स्थिती"],
["मिल्किंग","Milking","दूध काढणे"],["चिलिंग/टेस्ट","Chilling/Test","चिलिंग/टेस्ट"],["रूट पर","On route","मार्गावर"],["डिलीवरी","Delivery","डिलिव्हरी"],
["फैट","Fat","फॅट"],
["🥛 गिर गाय:","🥛 Gir cow:","🥛 गीर गाय:"],["🐃 भैंस:","🐃 Buffalo:","🐃 म्हैस:"],
["सब्सक्रिप्शन सक्रिय","Subscription active","सबस्क्रिप्शन सक्रिय"],
["एडिट करें","Edit","बदला"],
["सब्सक्रिप्शन","Subscription","सबस्क्रिप्शन"],
["कल के लिए Pause","Pause for tomorrow","उद्यासाठी Pause"],
["कल फिर शुरू करें","Resume tomorrow","उद्या पुन्हा सुरू करा"],
["लंबी छुट्टी","Long holiday","दीर्घ सुट्टी"],
["डिलीवरी समय चुनें:","Choose delivery time:","डिलिव्हरीची वेळ निवडा:"],
["🌅 5:30 AM - 7:00 AM (सुबह)","🌅 5:30 AM - 7:00 AM (morning)","🌅 5:30 AM - 7:00 AM (सकाळी)"],
["☀️ 7:00 AM - 8:30 AM (लेट)","☀️ 7:00 AM - 8:30 AM (late)","☀️ 7:00 AM - 8:30 AM (उशिरा)"],
["घंटी बजाएं?","Ring the doorbell?","दारावरची घंटी वाजवायची?"],
["नहीं (साइलेंट मोड)","No (silent mode)","नाही (सायलेंट मोड)"],
["हाँ (डोरबेल बजाएंगे)","Yes (we will ring the bell)","होय (घंटी वाजवू)"],
["सभी (11)","All (11)","सर्व (11)"],
["🥛 ताजा दूध","🥛 Fresh milk","🥛 ताजे दूध"],["🧀 सफेद पनीर","🧀 White paneer","🧀 पांढरे पनीर"],["🧈 बिलोना घी","🧈 Bilona ghee","🧈 बिलोना तूप"],["🥬 खेत की सब्जियां","🥬 Farm vegetables","🥬 शेतातील भाज्या"],
["ऑर्डर","Order","ऑर्डर"],["ऑर्डर बंद","Closed","बंद"],["Out of Stock","Out of Stock","स्टॉक संपला"],
["सीधा जमवारामगढ़ व सिरसी फार्म से","Straight from Jamwaramgarh & Sirsi farm","थेट जमवारामगढ व सिरसी फार्मवरून"],
["🌿 फार्म व हाइजीन की झलकियां","🌿 Farm & hygiene glimpses","🌿 फार्म व स्वच्छतेची झलक"],
["100% प्राकृतिक","100% Natural","100% नैसर्गिक"],
["स्टेनलेस स्टील बर्तन, बिना हाथ लगाए मिल्किंग और खेत से सीधी ताजी कटाई:","Stainless-steel vessels, hands-free milking and fresh harvest straight from the field:","स्टेनलेस स्टीलची भांडी, हात न लावता दूध काढणे आणि शेतातून थेट ताजी कापणी:"],
["शुद्ध, असंसाधित व अनपाश्चुरीकृत प्राकृतिक धार","Pure, unprocessed, unpasteurised natural milk","शुद्ध, प्रक्रिया न केलेले व अपाश्चराइज्ड नैसर्गिक दूध"],
["खाद्य सुरक्षा एवं मानक प्राधिकरण","Food Safety & Standards Authority","अन्न सुरक्षा व मानक प्राधिकरण"],
["सत्यापित","Verified","पडताळलेले"],
["रिफंड पॉलिसी","Refund policy","रिफंड धोरण"],["नियम व शर्तें","Terms & Conditions","नियम व अटी"],
["सुरक्षित 100% डिजिटल पेमेंट","Safe 100% digital payments","सुरक्षित 100% डिजिटल पेमेंट"],
["पे","Pe","पे"],
["फार्म पता: जमवारामगढ़ घाटी व सिरसी रोड फार्म, जयपुर, राजस्थान","Farm address: Jamwaramgarh Ghati & Sirsi Road farm, Jaipur, Rajasthan","फार्म पत्ता: जमवारामगढ घाटी व सिरसी रोड फार्म, जयपूर, राजस्थान"],
["हेल्पलाइन: WhatsApp {0} | ईमेल: {1}","Helpline: WhatsApp {0} | Email: {1}","हेल्पलाइन: WhatsApp {0} | ईमेल: {1}"],
["© 2026 आज की धार (Aaj Ki Dhar). सर्वाधिकार सुरक्षित (All Rights Reserved).","© 2026 Aaj Ki Dhar. All Rights Reserved.","© 2026 आज की धार (Aaj Ki Dhar). सर्व हक्क राखीव."],
["होम","Home","होम"],["मेरे ऑर्डर","My orders","माझे ऑर्डर"],["प्रोफ़ाइल","Profile","प्रोफाइल"],
// ---- चैटबॉट ----
["आज की धार AI सहायक","Aaj Ki Dhar AI Assistant","आज की धार AI सहाय्यक"],["ग्राहक सहायता","Customer support","ग्राहक सहाय्य"],
["🔐 लॉगिन / साइन-अप","🔐 Log in / Sign up","🔐 लॉग इन / साइन-अप"],["🥛 फैट व SNF","🥛 Fat & SNF","🥛 फॅट व SNF"],["🏷 रेट","🏷 Rates","🏷 दर"],["🚚 डिलीवरी","🚚 Delivery","🚚 डिलिव्हरी"],["💳 पेमेंट","💳 Payment","💳 पेमेंट"],["🌿 फार्म","🌿 Farm","🌿 फार्म"],["⚠️ समस्या","⚠️ Problem","⚠️ समस्या"],
["अपना ईमेल या संदेश लिखें...","Type your email or message...","तुमचा ईमेल किंवा संदेश लिहा..."],
// ---- वॉलेट रिचार्ज ----
["वॉलेट रिचार्ज","Wallet recharge","वॉलेट रिचार्ज"],
["या अपनी राशि लिखें (₹)","Or enter your own amount (₹)","किंवा तुमची रक्कम लिहा (₹)"],
["भुगतान के बाद 12 अंकों का UTR / Ref No. दर्ज करें:","After paying, enter the 12-digit UTR / Ref No.:","पेमेंटनंतर 12 अंकी UTR / Ref No. टाका:"],
["उदा. 428912345678","e.g. 428912345678","उदा. 428912345678"],
["UTR का सत्यापन होते ही राशि वॉलेट में जोड़ दी जाएगी।","The amount is added to your wallet as soon as the UTR is verified.","UTR ची पडताळणी होताच रक्कम वॉलेटमध्ये जमा केली जाईल."],
["UTR सबमिट करें (सत्यापन अनुरोध भेजें)","Submit UTR (send for verification)","UTR सबमिट करा (पडताळणीसाठी पाठवा)"],
["+ रिचार्ज","+ Recharge","+ रिचार्ज"],
["स्कैन करें:","Scan:","स्कॅन करा:"],
["PhonePe / GPay / Paytm से भुगतान करें","Pay with PhonePe / GPay / Paytm","PhonePe / GPay / Paytm ने पेमेंट करा"],
["UPI ऐप खोलकर ₹{0} भरें","Open UPI app and pay ₹{0}","UPI ॲप उघडून ₹{0} भरा"],
["ऑनलाइन रिचार्ज अभी बंद है। कृपया WhatsApp पर संपर्क करें।","Online recharge is closed right now. Please contact us on WhatsApp.","ऑनलाइन रिचार्ज सध्या बंद आहे. कृपया WhatsApp वर संपर्क करा."],
// ---- ऑर्डर मोडल ----
["ऑर्डर व भुगतान पुष्टि","Order & payment confirmation","ऑर्डर व पेमेंट पुष्टी"],
["मात्रा","Quantity","प्रमाण"],["कुल:","Total:","एकूण:"],
["भुगतान का माध्यम चुनें:","Choose payment method:","पेमेंटचा पर्याय निवडा:"],
["ऑर्डर कन्फर्म करें","Confirm order","ऑर्डर निश्चित करा"],
["वॉलेट","Wallet","वॉलेट"],["UPI ऐप","UPI app","UPI ॲप"],["QR स्कैन","QR scan","QR स्कॅन"],["कैश ऑन डिलीवरी","Cash on delivery","कॅश ऑन डिलिव्हरी"],
["उपलब्ध वॉलेट बैलेंस:","Available wallet balance:","उपलब्ध वॉलेट बॅलन्स:"],
["ऑर्डर कन्फर्म होते ही राशि वॉलेट से काट ली जाएगी।","The amount is deducted from your wallet once you confirm.","ऑर्डर निश्चित होताच रक्कम वॉलेटमधून कापली जाईल."],
["₹{0} वॉलेट से काटें व ऑर्डर करें","Pay ₹{0} from wallet & order","₹{0} वॉलेटमधून कापा व ऑर्डर करा"],
["वॉलेट में ₹{0} कम हैं - रिचार्ज करें","₹{0} short in wallet - recharge","वॉलेटमध्ये ₹{0} कमी आहेत - रिचार्ज करा"],
["QR स्कैन करके ₹{0} भरें व UTR दर्ज करें:","Scan the QR, pay ₹{0} and enter the UTR:","QR स्कॅन करून ₹{0} भरा व UTR टाका:"],
["अपने UPI ऐप में ₹{0} भरें व UTR दर्ज करें:","Pay ₹{0} in your UPI app and enter the UTR:","तुमच्या UPI ॲपमध्ये ₹{0} भरा व UTR टाका:"],
["UPI ऐप खोलें (₹{0})","Open UPI app (₹{0})","UPI ॲप उघडा (₹{0})"],
["12-अंकों का UTR नंबर:","12-digit UTR number:","12 अंकी UTR नंबर:"],
["बैंक Ref / UTR No.","Bank Ref / UTR No.","बँक Ref / UTR No."],
["UTR सबमिट करें (सत्यापन हेतु भेजें)","Submit UTR (send for verification)","UTR सबमिट करा (पडताळणीसाठी पाठवा)"],
["कैश ऑन डिलीवरी:","Cash on delivery:","कॅश ऑन डिलिव्हरी:"],
["डिलीवरी के समय ₹{0} नकद (या UPI) डिलीवरी बॉय को दें।","Pay ₹{0} in cash (or UPI) to the delivery person at delivery.","डिलिव्हरीच्या वेळी ₹{0} रोख (किंवा UPI) डिलिव्हरी बॉयला द्या."],
["कृपया सही छुट्टे रखें। बार-बार कैंसिल होने पर COD बंद हो सकता है।","Please keep exact change. COD may be stopped if orders are cancelled repeatedly.","कृपया सुटे पैसे ठेवा. वारंवार रद्द केल्यास COD बंद होऊ शकते."],
["कैश ऑन डिलीवरी से ऑर्डर करें (₹{0})","Order with cash on delivery (₹{0})","कॅश ऑन डिलिव्हरीने ऑर्डर करा (₹{0})"],
["अभी ऑनलाइन ऑर्डर बंद है। कृपया WhatsApp पर संपर्क करें।","Online ordering is closed right now. Please contact us on WhatsApp.","ऑनलाइन ऑर्डर सध्या बंद आहेत. कृपया WhatsApp वर संपर्क करा."],
["ऑर्डर उपलब्ध नहीं","Order unavailable","ऑर्डर उपलब्ध नाही"],
// ---- सब्सक्रिप्शन ----
["सब्सक्रिप्शन प्लान","Subscription plan","सबस्क्रिप्शन प्लॅन"],
["आइटम व तारीखें चुनें — रोज़ सुबह ताजी धार, पूरा पैसा एडवांस वॉलेट से","Pick items and dates — fresh milk every morning, fully prepaid from your wallet","आयटम व तारखा निवडा — रोज सकाळी ताजे दूध, पूर्ण रक्कम आधी वॉलेटमधून"],
["कितने दिन के लिए?","For how many days?","किती दिवसांसाठी?"],
["7 दिन","7 days","7 दिवस"],["15 दिन","15 days","15 दिवस"],["1 महीना","1 month","1 महिना"],["अपनी तारीखें","Custom dates","स्वतःच्या तारखा"],
["शुरू की तारीख","Start date","सुरुवातीची तारीख"],["अंतिम तारीख","End date","शेवटची तारीख"],
["अधिकतम 62 दिन। शुरुआत कल या उसके बाद की तारीख से हो सकती है।","Maximum 62 days. You can start from tomorrow or later.","कमाल 62 दिवस. उद्यापासून किंवा त्यानंतरच्या तारखेपासून सुरू करता येईल."],
["रोज़ क्या चाहिए?","What do you need daily?","रोज काय हवे?"],
["दैनिक खर्च (Daily Total):","Daily total:","दैनिक खर्च:"],["कुल दिन:","Total days:","एकूण दिवस:"],
["एडवांस राशि (दिन × दैनिक खर्च):","Advance amount (days × daily total):","ॲडव्हान्स रक्कम (दिवस × दैनिक खर्च):"],
["वर्तमान वॉलेट बैलेंस:","Current wallet balance:","सध्याचा वॉलेट बॅलन्स:"],
["{0} दिन","{0} days","{0} दिवस"],
["₹{0} (+₹{1} पुराना एडवांस)","₹{0} (+₹{1} old advance)","₹{0} (+₹{1} जुने ॲडव्हान्स)"],
["सब्सक्रिप्शन सक्रिय करें","Activate subscription","सबस्क्रिप्शन सक्रिय करा"],
["सब्सक्रिप्शन बंद करें (बचा एडवांस वापस वॉलेट में)","Cancel subscription (unused advance returns to wallet)","सबस्क्रिप्शन बंद करा (उरलेले ॲडव्हान्स वॉलेटमध्ये परत)"],
["रोज़ के एक बार के ऑर्डर के लिए होम स्क्रीन पर प्रोडक्ट के 'ऑर्डर' बटन का उपयोग करें।","For one-time orders, use the 'Order' button on a product on the home screen.","एकदा ऑर्डर करण्यासाठी होम स्क्रीनवरील प्रॉडक्टचे 'ऑर्डर' बटन वापरा."],
["कृपया सही शुरू व अंतिम तारीख चुनें","Please choose valid start and end dates","कृपया योग्य सुरुवातीची व शेवटची तारीख निवडा"],
["ऑर्डर बंद है (रात 10 बजे के बाद)","Orders closed (after 10 PM)","ऑर्डर बंद (रात्री 10 नंतर)"],
["कृपया कम से कम 1 आइटम चुनें","Please select at least 1 item","कृपया किमान 1 आयटम निवडा"],
["₹{0} वॉलेट से काटें व सब्सक्रिप्शन अपडेट करें","Pay ₹{0} from wallet & update subscription","₹{0} वॉलेटमधून कापा व सबस्क्रिप्शन अपडेट करा"],
["₹{0} वॉलेट से काटें व सब्सक्रिप्शन एक्टिव करें","Pay ₹{0} from wallet & activate subscription","₹{0} वॉलेटमधून कापा व सबस्क्रिप्शन सक्रिय करा"],
["सब्सक्रिप्शन सक्रिय: {0} से {1} (₹{2}/दिन)","Subscription active: {0} to {1} (₹{2}/day)","सबस्क्रिप्शन सक्रिय: {0} ते {1} (₹{2}/दिवस)"],
["दैनिक बास्केट एक्टिव (₹{0}/दिन • बफर ₹{1} जमा)","Daily basket active (₹{0}/day • ₹{1} advance held)","दैनिक बास्केट सक्रिय (₹{0}/दिवस • ₹{1} ॲडव्हान्स जमा)"],
// ---- मेरे ऑर्डर ----
["सब्सक्रिप्शन","Subscription","सबस्क्रिप्शन"],["लेन-देन","Transactions","व्यवहार"],
["सभी","All","सर्व"],["चल रहे","Ongoing","सुरू असलेले"],["डिलीवर हुए","Delivered","डिलिव्हर झाले"],["रद्द","Cancelled","रद्द"],
["ऑर्डर दर्ज","Order placed","ऑर्डर नोंदवला"],["सत्यापन बाकी","Verification pending","पडताळणी बाकी"],["स्वीकृत","Accepted","स्वीकृत"],["डिलीवर हुआ","Delivered","डिलिव्हर झाले"],
["✖ ऑर्डर अस्वीकृत / रद्द","✖ Order rejected / cancelled","✖ ऑर्डर नाकारला / रद्द"],
["✅ डिलीवर हुआ","✅ Delivered","✅ डिलिव्हर झाले"],["⏳ सत्यापन बाकी","⏳ Verification pending","⏳ पडताळणी बाकी"],["✔ स्वीकृत","✔ Accepted","✔ स्वीकृत"],["✖ अस्वीकृत","✖ Rejected","✖ नाकारले"],
["डिलीवरी: {0}","Delivery: {0}","डिलिव्हरी: {0}"],
["अभी कोई ऑर्डर नहीं।","No orders yet.","अजून कोणतेही ऑर्डर नाहीत."],["अभी कोई रिचार्ज नहीं।","No recharges yet.","अजून कोणतेही रिचार्ज नाहीत."],["अभी कोई लेन-देन नहीं।","No transactions yet.","अजून कोणतेही व्यवहार नाहीत."],
["अभी कोई सब्सक्रिप्शन सक्रिय नहीं है।","No active subscription.","कोणतेही सबस्क्रिप्शन सक्रिय नाही."],
["सब्सक्रिप्शन शुरू करें","Start a subscription","सबस्क्रिप्शन सुरू करा"],["सक्रिय सब्सक्रिप्शन","Active subscription","सक्रिय सबस्क्रिप्शन"],
["{0} से {1} तक","{0} to {1}","{0} ते {1}"],
["दैनिक खर्च:","Daily cost:","दैनिक खर्च:"],["• जमा एडवांस:","• Advance held:","• जमा ॲडव्हान्स:"],["₹{0}/दिन","₹{0}/day","₹{0}/दिवस"],
["सब्सक्रिप्शन बदलें / बंद करें","Change / cancel subscription","सबस्क्रिप्शन बदला / बंद करा"],
["वॉलेट लेन-देन","Wallet transactions","वॉलेट व्यवहार"],["मेरे रिचार्ज","My recharges","माझे रिचार्ज"],
["मेरा वॉलेट बैलेंस","My wallet balance","माझा वॉलेट बॅलन्स"],
// ---- प्रोफ़ाइल ----
["मेरी प्रोफ़ाइल","My profile","माझी प्रोफाइल"],
["ट्रैक करें व हिस्ट्री देखें","Track orders & view history","ट्रॅक करा व इतिहास पाहा"],
["भाषा (Language)","Language","भाषा (Language)"],
["प्रोफ़ाइल अपडेट","Update profile","प्रोफाइल अपडेट"],["प्रोफ़ाइल अपडेट करें","Update profile","प्रोफाइल अपडेट करा"],
["ईमेल आईडी (लॉगिन ईमेल):","Email ID (login email):","ईमेल आयडी (लॉगिन ईमेल):"],
["ईमेल आपका लॉगिन है, इसे बदलने के लिए WhatsApp पर संपर्क करें।","Your email is your login. To change it, contact us on WhatsApp.","ईमेल हाच तुमचा लॉगिन आहे; बदलण्यासाठी WhatsApp वर संपर्क करा."],
["लॉग आउट","Log out","लॉग आउट"],["लॉग इन","Log in","लॉग इन"],["साइन अप","Sign up","साइन अप"],["साइन अप (नया खाता)","Sign up (new account)","साइन अप (नवीन खाते)"],
["आप अभी लॉगिन नहीं हैं।","You are not logged in.","तुम्ही सध्या लॉग इन नाही."],
["ऑर्डर, वॉलेट व सब्सक्रिप्शन के लिए अपने ईमेल से OTP द्वारा लॉगिन करें या नया खाता बनाएं।","Log in with an email OTP, or create a new account, to order and use the wallet and subscriptions.","ऑर्डर, वॉलेट व सबस्क्रिप्शनसाठी ईमेलवरील OTP ने लॉग इन करा किंवा नवीन खाते उघडा."],
["अतिथि (लॉगिन नहीं)","Guest (not logged in)","पाहुणे (लॉग इन नाही)"],
// ---- फ़ॉर्म फ़ील्ड ----
["पहला नाम","First name","पहिले नाव"],["अंतिम नाम","Last name","आडनाव"],["मध्य नाम (वैकल्पिक)","Middle name (optional)","मधले नाव (ऐच्छिक)"],
["मोबाइल नंबर (प्राइमरी)","Primary mobile number","प्राथमिक मोबाइल नंबर"],["10 अंकों का नंबर","10-digit number","10 अंकी नंबर"],
["पता लाइन 1 (मकान/फ्लैट नं., गली)","Address line 1 (house/flat no., street)","पत्ता ओळ 1 (घर/फ्लॅट नं., गल्ली)"],
["पता लाइन 2 (कॉलोनी/सेक्टर/इलाका)","Address line 2 (colony/sector/area)","पत्ता ओळ 2 (कॉलनी/सेक्टर/परिसर)"],
["पता लाइन 3 (वैकल्पिक)","Address line 3 (optional)","पत्ता ओळ 3 (ऐच्छिक)"],["लैंडमार्क (वैकल्पिक)","Landmark (optional)","जवळची खूण (ऐच्छिक)"],
["शहर","City","शहर"],["पिन कोड","PIN code","पिन कोड"],["जयपुर","Jaipur","जयपूर"],
["ईमेल आईडी","Email ID","ईमेल आयडी"],["ईमेल (सत्यापित)","Email (verified)","ईमेल (पडताळलेला)"],
// ---- लॉगिन पॉपअप ----
["लॉग इन करें","Log in","लॉग इन करा"],["नया खाता बनाएं","Create a new account","नवीन खाते उघडा"],["ईमेल सत्यापन","Email verification","ईमेल पडताळणी"],["अपना विवरण भरें","Fill in your details","तुमचा तपशील भरा"],
["OTP भेजें","Send OTP","OTP पाठवा"],["OTP भेजकर साइन अप करें","Send OTP & sign up","OTP पाठवून साइन अप करा"],
["नया खाता बनाने के लिए नीचे सारा विवरण भरें (लाल * वाले ज़रूरी हैं)। ईमेल पर 6-अंकों का OTP आएगा; पासवर्ड की ज़रूरत नहीं।","Fill in all the details below (fields with a red * are required). A 6-digit OTP will be sent to your email; no password needed.","नवीन खाते उघडण्यासाठी खालील सर्व तपशील भरा (लाल * असलेले आवश्यक). ईमेलवर 6 अंकी OTP येईल; पासवर्ड नको."],
["अपना रजिस्टर ईमेल लिखें। उस पर 6-अंकों का OTP आएगा; पासवर्ड की ज़रूरत नहीं। नए ग्राहक पहले 'साइन अप' करें।","Enter your registered email. A 6-digit OTP will be sent to it; no password needed. New customers should 'Sign up' first.","तुमचा नोंदणीकृत ईमेल लिहा. त्यावर 6 अंकी OTP येईल; पासवर्ड नको. नवीन ग्राहकांनी आधी 'साइन अप' करावे."],
["OTP भेजा गया:","OTP sent to:","OTP पाठवला:"],
["— न दिखे तो Spam/Promotions फोल्डर देखें।","— if you can't see it, check the Spam/Promotions folder.","— दिसत नसेल तर Spam/Promotions फोल्डर पाहा."],
["OTP आने में 1-2 मिनट लग सकते हैं। कृपया बार-बार दोबारा न भेजें।","The OTP can take 1-2 minutes to arrive. Please don't resend repeatedly.","OTP येण्यास 1-2 मिनिटे लागू शकतात. कृपया वारंवार पुन्हा पाठवू नका."],
["OTP लिखें","Enter OTP","OTP टाका"],["सत्यापित करें","Verify","पडताळा"],
["OTP दोबारा भेजें","Resend OTP","OTP पुन्हा पाठवा"],["OTP दोबारा भेजें ({0}s)","Resend OTP ({0}s)","OTP पुन्हा पाठवा ({0}s)"],["ईमेल बदलें","Change email","ईमेल बदला"],
["खाता बनाएं","Create account","खाते उघडा"],["संस्करण v4","Version v4","आवृत्ती v4"],
// ---- ब्लॉक स्क्रीन ----
["आपका खाता ब्लॉक कर दिया गया है","Your account has been blocked","तुमचे खाते ब्लॉक केले आहे"],
["इस खाते से अभी ऐप का उपयोग नहीं किया जा सकता। अनब्लॉक करवाने के लिए कृपया सपोर्ट से संपर्क करें।","This account cannot use the app right now. To get it unblocked, please contact support.","या खात्याने सध्या ॲप वापरता येत नाही. अनब्लॉक करण्यासाठी कृपया सपोर्टशी संपर्क करा."],
["सपोर्ट से संपर्क करें","Contact support","सपोर्टशी संपर्क करा"],
["WhatsApp पर संपर्क करें","Contact on WhatsApp","WhatsApp वर संपर्क करा"],
// ---- पॉज / छुट्टी ----
["लंबी छुट्टी (Pause Deliveries)","Long holiday (pause deliveries)","दीर्घ सुट्टी (डिलिव्हरी थांबवा)"],
["छुट्टी के दौरान कोई पैसा नहीं कटेगा।","No money is charged during the holiday.","सुट्टीच्या काळात कोणतेही पैसे कापले जाणार नाहीत."],
["कब से बंद करें (Start Date):","Pause from (start date):","कधीपासून बंद करायचे (सुरुवातीची तारीख):"],
["कब तक बंद रखें (End Date):","Pause until (end date):","कधीपर्यंत बंद ठेवायचे (शेवटची तारीख):"],
["छुट्टी लागू करें","Apply holiday","सुट्टी लागू करा"],
["{0} से {1} तक बंद","Paused {0} to {1}","{0} ते {1} बंद"],
["समझ गया","Got it","समजले"],["नीति विवरण","Policy details","धोरण तपशील"],["सूचना","Notice","सूचना"],
["रिफंड व रिटर्न पॉलिसी","Refund & return policy","रिफंड व रिटर्न धोरण"],["नियम व शर्तें (Terms & Conditions)","Terms & Conditions","नियम व अटी"],
["आज की धार | गिर गाय, मुर्राह भैंस का दूध, ताजा सफेद पनीर, बिलोना घी व सब्जियां","Aaj Ki Dhar | Gir cow & Murrah buffalo milk, fresh white paneer, bilona ghee & vegetables","आज की धार | गीर गाय, मुर्राह म्हशीचे दूध, ताजे पांढरे पनीर, बिलोना तूप व भाज्या"]
]);
window.I18N._add([
["⚠️ {0}","⚠️ {0}","⚠️ {0}"],
["⚠️ सर्वर (Supabase) कनेक्ट नहीं है — लॉगिन व ऑर्डर अभी बंद हैं।","⚠️ Server is not connected — login and orders are unavailable right now.","⚠️ सर्व्हर जोडलेला नाही — लॉग इन व ऑर्डर सध्या बंद आहेत."],
["कृपया पहले लॉगिन करें।","Please log in first.","कृपया आधी लॉग इन करा."],
["सर्वर में समस्या आई, कृपया दोबारा कोशिश करें।","Something went wrong on the server, please try again.","सर्व्हरमध्ये समस्या आली, कृपया पुन्हा प्रयत्न करा."],
["सर्वर कनेक्ट नहीं है। कृपया बाद में कोशिश करें।","Server is not connected. Please try again later.","सर्व्हर जोडलेला नाही. कृपया नंतर प्रयत्न करा."],
["सर्वर कनेक्ट नहीं है।","Server is not connected.","सर्व्हर जोडलेला नाही."],
["सर्वर से जवाब नहीं मिला।","No response from the server.","सर्व्हरकडून प्रतिसाद मिळाला नाही."],
["इंटरनेट/सर्वर की समस्या, कृपया दोबारा कोशिश करें।","Internet/server problem, please try again.","इंटरनेट/सर्व्हर समस्या, कृपया पुन्हा प्रयत्न करा."],
["यह सुविधा अभी सर्वर पर चालू नहीं है।","This feature is not enabled on the server yet.","ही सुविधा सर्व्हरवर अजून सुरू नाही."],
["आपका खाता ब्लॉक है। कृपया सपोर्ट से संपर्क करें।","Your account is blocked. Please contact support.","तुमचे खाते ब्लॉक आहे. कृपया सपोर्टशी संपर्क करा."],
["रात 10 बजे के बाद ऑर्डर बंद हैं। रात 12 बजे के बाद फिर कोशिश करें।","Orders are closed after 10 PM. Please try again after 12 midnight.","रात्री 10 नंतर ऑर्डर बंद आहेत. रात्री 12 नंतर पुन्हा प्रयत्न करा."],
["पहले लॉगिन / साइन अप करें","Please log in / sign up first","आधी लॉग इन / साइन अप करा"],
["✅ लॉग आउट हो गए। दोबारा आने के लिए प्रोफ़ाइल से लॉग इन या साइन अप करें।","✅ Logged out. To come back, log in or sign up from Profile.","✅ लॉग आउट झाले. पुन्हा येण्यासाठी प्रोफाइलमधून लॉग इन किंवा साइन अप करा."],
["स्लॉट चुना गया: {0}","Slot selected: {0}","स्लॉट निवडला: {0}"],
// ---- लॉगिन संदेश ----
["कृपया 1 मिनट रुककर दोबारा कोशिश करें।","Please wait 1 minute and try again.","कृपया 1 मिनिट थांबून पुन्हा प्रयत्न करा."],
["OTP सही नहीं है या समय समाप्त हो गया।","The OTP is incorrect or has expired.","OTP चुकीचा आहे किंवा वेळ संपली आहे."],
["यह ईमेल स्वीकार नहीं हुआ। कृपया सही ईमेल लिखें।","This email was not accepted. Please enter a valid email.","हा ईमेल स्वीकारला गेला नाही. कृपया योग्य ईमेल लिहा."],
["कुछ गड़बड़ हुई, कृपया दोबारा कोशिश करें।","Something went wrong, please try again.","काहीतरी चुकले, कृपया पुन्हा प्रयत्न करा."],
["यह ईमेल रजिस्टर नहीं है। कृपया पहले साइन अप करें।","This email is not registered. Please sign up first.","हा ईमेल नोंदणीकृत नाही. कृपया आधी साइन अप करा."],
["यह ईमेल रजिस्टर नहीं है। कृपया पहले साइन अप करें। नीचे अपना विवरण भरकर साइन अप करें।","This email is not registered. Please sign up first — fill in your details below.","हा ईमेल नोंदणीकृत नाही. कृपया आधी साइन अप करा — खाली तुमचा तपशील भरा."],
["आप पहले से लॉगिन हैं।","You are already logged in.","तुम्ही आधीच लॉग इन आहात."],
["आपका ईमेल सत्यापित है। खाता पूरा करने के लिए विवरण भरें।","Your email is verified. Fill in your details to complete the account.","तुमचा ईमेल पडताळलेला आहे. खाते पूर्ण करण्यासाठी तपशील भरा."],
["कृपया पहला नाम सही लिखें।","Please enter a valid first name.","कृपया पहिले नाव योग्य लिहा."],
["कृपया मध्य नाम सही लिखें।","Please enter a valid middle name.","कृपया मधले नाव योग्य लिहा."],
["कृपया अंतिम नाम सही लिखें।","Please enter a valid last name.","कृपया आडनाव योग्य लिहा."],
["कृपया सही 10-अंकों का मोबाइल नंबर लिखें।","Please enter a valid 10-digit mobile number.","कृपया योग्य 10 अंकी मोबाइल नंबर लिहा."],
["कृपया पता लाइन 1 लिखें (मकान/फ्लैट नं., गली)।","Please enter address line 1 (house/flat no., street).","कृपया पत्ता ओळ 1 लिहा (घर/फ्लॅट नं., गल्ली)."],
["कृपया पता लाइन 2 लिखें (कॉलोनी/सेक्टर/इलाका)।","Please enter address line 2 (colony/sector/area).","कृपया पत्ता ओळ 2 लिहा (कॉलनी/सेक्टर/परिसर)."],
["कृपया शहर का नाम लिखें।","Please enter the city.","कृपया शहराचे नाव लिहा."],
["कृपया सही 6-अंकों का पिन कोड लिखें।","Please enter a valid 6-digit PIN code.","कृपया योग्य 6 अंकी पिन कोड लिहा."],
["कृपया सही ईमेल आईडी लिखें (जैसे name@gmail.com)।","Please enter a valid email ID (like name@gmail.com).","कृपया योग्य ईमेल आयडी लिहा (उदा. name@gmail.com)."],
["⏳ OTP भेजा जा रहा है...","⏳ Sending OTP...","⏳ OTP पाठवला जात आहे..."],
["✅ नया OTP भेज दिया गया है।","✅ A new OTP has been sent.","✅ नवीन OTP पाठवला आहे."],
["ईमेल में आया 6-अंकों का OTP लिखें।","Enter the 6-digit OTP from your email.","ईमेलमध्ये आलेला 6 अंकी OTP लिहा."],
["बहुत बार गलत OTP। सुरक्षा के लिए रोक दिया गया है, कृपया नया OTP मंगाएं।","Too many wrong OTPs. Blocked for safety — please request a new OTP.","खूप वेळा चुकीचा OTP. सुरक्षेसाठी थांबवले आहे, कृपया नवीन OTP मागवा."],
["❌ OTP सही नहीं है या समय समाप्त हो गया। (बचे प्रयास: {0})","❌ The OTP is incorrect or has expired. (Attempts left: {0})","❌ OTP चुकीचा आहे किंवा वेळ संपली आहे. (उरलेले प्रयत्न: {0})"],
["इस ईमेल से खाता पहले से था, आप लॉगिन हो गए।","An account already existed for this email — you are now logged in.","या ईमेलवर खाते आधीच होते, तुम्ही लॉग इन झालात."],
["✅ ईमेल सत्यापित! नया खाता पूरा करने के लिए विवरण भरें।","✅ Email verified! Fill in your details to complete the new account.","✅ ईमेल पडताळला! नवीन खाते पूर्ण करण्यासाठी तपशील भरा."],
["खाता नहीं बन सका, कृपया दोबारा कोशिश करें।","The account could not be created, please try again.","खाते उघडता आले नाही, कृपया पुन्हा प्रयत्न करा."],
["🎉 खाता बन गया! स्वागत है।","🎉 Account created! Welcome.","🎉 खाते उघडले! स्वागत आहे."],
["🎉 खाता बन गया! स्वागत है। ₹{0} वेलकम बोनस मिला।","🎉 Account created! Welcome. You got a ₹{0} welcome bonus.","🎉 खाते उघडले! स्वागत आहे. ₹{0} वेलकम बोनस मिळाला."],
["✅ लॉगिन सफल! स्वागत है {0} जी।","✅ Login successful! Welcome, {0}.","✅ लॉग इन यशस्वी! स्वागत आहे {0}."],
// ---- रिचार्ज / ऑर्डर ----
["वॉलेट रिचार्ज के लिए पहले लॉगिन करें","Log in first to recharge the wallet","वॉलेट रिचार्जसाठी आधी लॉग इन करा"],
["ऑनलाइन रिचार्ज अभी बंद है।","Online recharge is closed right now.","ऑनलाइन रिचार्ज सध्या बंद आहे."],
["⚠️ राशि ₹10 से ₹50,000 के बीच दर्ज करें!","⚠️ Enter an amount between ₹10 and ₹50,000!","⚠️ ₹10 ते ₹50,000 दरम्यान रक्कम टाका!"],
["⚠️ कृपया बैंक ऐप से 12 अंकों का वैध UTR नंबर दर्ज करें!","⚠️ Please enter a valid 12-digit UTR number from your bank app!","⚠️ कृपया बँक ॲपमधून 12 अंकी वैध UTR नंबर टाका!"],
["अनुरोध नहीं भेजा जा सका।","The request could not be sent.","विनंती पाठवता आली नाही."],
["✅ UTR दर्ज हुआ! सत्यापन होते ही वॉलेट में पैसे जुड़ जाएंगे।","✅ UTR recorded! The money will be added to your wallet once verified.","✅ UTR नोंदवला! पडताळणी होताच वॉलेटमध्ये पैसे जमा होतील."],
["सब्सक्रिप्शन के लिए पहले लॉगिन करें","Log in first to subscribe","सबस्क्रिप्शनसाठी आधी लॉग इन करा"],
["ऑर्डर के लिए पहले लॉगिन / साइन अप करें","Log in / sign up first to order","ऑर्डरसाठी आधी लॉग इन / साइन अप करा"],
["अपने ऑर्डर देखने के लिए पहले लॉगिन करें","Log in first to see your orders","ऑर्डर पाहण्यासाठी आधी लॉग इन करा"],
["यह आइटम अभी आउट-ऑफ-स्टॉक है!","This item is out of stock right now!","हा आयटम सध्या स्टॉकमध्ये नाही!"],
["ऑर्डर नहीं हो सका।","The order could not be placed.","ऑर्डर देता आला नाही."],
["✅ ₹{0} वॉलेट से कटे! ऑर्डर {1} डिलीवर होगा।","✅ ₹{0} deducted from wallet! Order will be delivered {1}.","✅ ₹{0} वॉलेटमधून कापले! ऑर्डर {1} डिलिव्हर होईल."],
["✅ ऑर्डर दर्ज! {0} डिलीवरी पर ₹{1} दें।","✅ Order placed! Pay ₹{1} on delivery {0}.","✅ ऑर्डर नोंदवला! {0} डिलिव्हरीवेळी ₹{1} द्या."],
["✅ ऑर्डर व UTR दर्ज हुआ! सत्यापन होते ही यह स्वीकृत हो जाएगा।","✅ Order and UTR recorded! It will be accepted once verified.","✅ ऑर्डर व UTR नोंदवला! पडताळणी होताच तो स्वीकृत होईल."],
["कल सुबह","tomorrow morning","उद्या सकाळी"],
["क्या आप सब्सक्रिप्शन बंद करना चाहते हैं? बचा हुआ एडवांस वॉलेट में लौटा दिया जाएगा।","Cancel the subscription? Any unused advance will be returned to your wallet.","सबस्क्रिप्शन बंद करायचे आहे का? उरलेले ॲडव्हान्स वॉलेटमध्ये परत केले जाईल."],
["⚠️ तारीख वाला सब्सक्रिप्शन अभी सर्वर पर चालू नहीं हुआ है। कृपया बाद में कोशिश करें।","⚠️ Date-based subscriptions are not enabled on the server yet. Please try again later.","⚠️ तारखेनुसार सबस्क्रिप्शन सर्व्हरवर अजून सुरू नाही. कृपया नंतर प्रयत्न करा."],
["सब्सक्रिप्शन नहीं हो सका।","The subscription could not be set up.","सबस्क्रिप्शन करता आले नाही."],
["🎉 ₹{0} वॉलेट से कटे! सब्सक्रिप्शन {1} से {2} तक सक्रिय हुआ।","🎉 ₹{0} deducted from wallet! Subscription active from {1} to {2}.","🎉 ₹{0} वॉलेटमधून कापले! सबस्क्रिप्शन {1} ते {2} पर्यंत सक्रिय झाले."],
["सब्सक्रिप्शन बंद हुआ, ₹{0} वॉलेट में लौटा दिए गए।","Subscription cancelled, ₹{0} returned to your wallet.","सबस्क्रिप्शन बंद झाले, ₹{0} वॉलेटमध्ये परत केले."],
["विफल","Failed","अयशस्वी"],
// ---- पॉज / छुट्टी / प्रोफ़ाइल ----
["पॉज के लिए पहले लॉगिन करें","Log in first to pause","पॉजसाठी आधी लॉग इन करा"],
["⏰ रात 10:00 बजे के बाद कल की डिलीवरी रोकी नहीं जा सकती।","⏰ Tomorrow's delivery cannot be paused after 10:00 PM.","⏰ रात्री 10:00 नंतर उद्याची डिलिव्हरी थांबवता येत नाही."],
["⏸ कल के लिए डिलीवरी रोक दी गई है","⏸ Delivery for tomorrow has been paused","⏸ उद्याची डिलिव्हरी थांबवली आहे"],
["▶ कल की डिलीवरी फिर से शुरू कर दी गई है!","▶ Tomorrow's delivery has been resumed!","▶ उद्याची डिलिव्हरी पुन्हा सुरू केली आहे!"],
["छुट्टी दर्ज करने के लिए पहले लॉगिन करें","Log in first to set a holiday","सुट्टी नोंदवण्यासाठी आधी लॉग इन करा"],
["कृपया दोनों तिथियां चुनें!","Please choose both dates!","कृपया दोन्ही तारखा निवडा!"],
["शुरू की तारीख आज या उसके बाद की हो।","The start date must be today or later.","सुरुवातीची तारीख आज किंवा नंतरची असावी."],
["समाप्ति की तारीख शुरू की तारीख से पहले नहीं हो सकती।","The end date cannot be before the start date.","शेवटची तारीख सुरुवातीच्या तारखेपूर्वी असू शकत नाही."],
["🏖 छुट्टी दर्ज हुई! इस दौरान कोई डिलीवरी नहीं होगी।","🏖 Holiday recorded! No deliveries during this period.","🏖 सुट्टी नोंदवली! या काळात डिलिव्हरी होणार नाही."],
["🚀 डिलीवरी तत्काल फिर से शुरू कर दी गई है!","🚀 Delivery has been resumed immediately!","🚀 डिलिव्हरी त्वरित पुन्हा सुरू केली आहे!"],
["✅ प्रोफ़ाइल विवरण सुरक्षित हुआ!","✅ Profile details saved!","✅ प्रोफाइल तपशील सुरक्षित केला!"],
["यह ऑर्डर","this order","हा ऑर्डर"]
]);
window.I18N._add([
// ---- प्रोडक्ट कैटलॉग ----
["A2 गिर गाय का कच्चा दूध","A2 Gir cow raw milk","A2 गीर गायीचे कच्चे दूध"],["देसी गिर गाय • 4 AM","Desi Gir cow • 4 AM","देशी गीर गाय • 4 AM"],["1 लीटर","1 litre","1 लिटर"],["कांच बोतल, अनपाश्चुरीकृत प्राकृतिक धार","Glass bottle, unpasteurised natural milk","काचेची बाटली, अपाश्चराइज्ड नैसर्गिक दूध"],
["देसी मुर्राह भैंस का गाढ़ा दूध","Desi Murrah buffalo thick milk","देशी मुर्राह म्हशीचे घट्ट दूध"],["मुर्राह नस्ल • 8.2% फैट","Murrah breed • 8.2% fat","मुर्राह जात • 8.2% फॅट"],["गाढ़ी मलाईदार धार, चाय व खीर स्पेशल","Thick, creamy milk — special for tea & kheer","घट्ट मलईदार दूध, चहा व खीरसाठी खास"],
["ताजा शुद्ध सफेद पनीर (कच्चा ब्लॉक)","Fresh pure white paneer (raw block)","ताजे शुद्ध पांढरे पनीर (कच्चा ब्लॉक)"],["नींबू से फाड़ा • नो स्टार्च","Curdled with lemon • no starch","लिंबाने फाडलेले • स्टार्च नाही"],["250 ग्राम ब्लॉक","250 g block","250 ग्रॅम ब्लॉक"],["स्पंजी, मखमली सफेद कच्चा पनीर","Spongy, velvety white raw paneer","स्पंजी, मखमली पांढरे कच्चे पनीर"],
["A2 गिर गाय का ताजा सफेद पनीर","A2 Gir cow fresh white paneer","A2 गीर गायीचे ताजे पांढरे पनीर"],["A2 गिर दूध","A2 Gir milk","A2 गीर दूध"],["250 ग्राम","250 g","250 ग्रॅम"],["पचने में बेहद हल्का, प्रोटीन युक्त कच्चा पनीर","Very light to digest, protein-rich raw paneer","पचायला अतिशय हलके, प्रथिनेयुक्त कच्चे पनीर"],
["डाइट लो-फैट ताजा सफेद पनीर","Diet low-fat fresh white paneer","डाएट लो-फॅट ताजे पांढरे पनीर"],["हाई प्रोटीन • लो कार्ब","High protein • low carb","हाय प्रोटीन • लो कार्ब"],["जिम डाइट व सलाद के लिए कच्चा पनीर","Raw paneer for gym diets & salads","जिम डाएट व सॅलडसाठी कच्चे पनीर"],
["A2 गिर गाय वैदिक बिलोना घी","A2 Gir cow Vedic bilona ghee","A2 गीर गाय वैदिक बिलोना तूप"],["लकड़ी की मथानी • स्वर्ण घी","Wooden churner • golden ghee","लाकडी रवी • सुवर्ण तूप"],["500 ml कांच जार","500 ml glass jar","500 ml काचेची बरणी"],["मिट्टी की मटकी में दही बिलोकर निकाला घी","Ghee churned from curd in a clay pot","मातीच्या मडक्यात दही घुसळून काढलेले तूप"],
["देसी मुर्राह भैंस का दानेदार घी","Desi Murrah buffalo granular ghee","देशी मुर्राह म्हशीचे दाणेदार तूप"],["सफेद ताजा मक्खन से निर्मित","Made from fresh white butter","ताज्या पांढऱ्या लोण्यापासून बनवलेले"],["1 लीटर टिन","1 litre tin","1 लिटर डबा"],["पारंपरिक दानेदार खुशबूदार भैंस का घी","Traditional granular aromatic buffalo ghee","पारंपरिक दाणेदार सुगंधी म्हशीचे तूप"],
["सीजनल ताजा पालक व मेथी बंच","Seasonal fresh spinach & fenugreek bunch","हंगामी ताजा पालक व मेथी जुडी"],["रात की ताजी कटाई","Freshly harvested overnight","रात्रीची ताजी कापणी"],["500 ग्राम","500 g","500 ग्रॅम"],["ओस की बूंदों के साथ खेत से सीधे तोड़ी पत्तियां","Leaves picked straight from the field with dewdrops","दवबिंदूंसह शेतातून थेट तोडलेली पाने"],
["खेत के देसी लाल टमाटर","Farm desi red tomatoes","शेतातील देशी लाल टोमॅटो"],["बिना केमिकल पके","Ripened without chemicals","रसायनांशिवाय पिकलेले"],["1 किग्रा","1 kg","1 किलो"],["खट्टा-मीठा स्वाद, पौधों से सीधे तोड़े गए","Tangy-sweet taste, picked straight from the plants","आंबट-गोड चव, झाडांवरून थेट तोडलेले"],
["खेत की ताजी हरी मिर्च व हरा धनिया","Fresh farm green chilli & coriander","शेतातील ताजी हिरवी मिरची व कोथिंबीर"],["दैनिक तड़का स्पेशल","Daily tadka special","रोजच्या फोडणीसाठी खास"],["250 ग्राम कॉम्बो","250 g combo","250 ग्रॅम कॉम्बो"],["तीखी ताजी मिर्च और खुशबूदार देसी धनिया","Spicy fresh chillies and fragrant desi coriander","तिखट ताजी मिरची आणि सुगंधी देशी कोथिंबीर"],
["दैनिक सीजनल ग्रीन वेजी बास्केट","Daily seasonal green veggie basket","रोजची हंगामी हिरव्या भाज्यांची बास्केट"],["4 मिक्स हरी सब्जियां","4 mixed green vegetables","4 मिश्र हिरव्या भाज्या"],["2 किग्रा कॉम्बो","2 kg combo","2 किलो कॉम्बो"],["ताजा तोरई, लौकी, शिमला मिर्च व हरी मिर्च","Fresh ridge gourd, bottle gourd, capsicum & green chilli","ताजी दोडकी, दुधी, ढोबळी मिरची व हिरवी मिरची"],
// ---- गैलरी ----
["देसी गिर गाय","Desi Gir cow","देशी गीर गाय"],["मुर्राह भैंस","Murrah buffalo","मुर्राह म्हैस"],["4 AM मिल्किंग","4 AM milking","4 AM दूध काढणे"],["पालक कटाई","Spinach harvest","पालक कापणी"],["देसी टमाटर","Desi tomatoes","देशी टोमॅटो"],["मिर्च व धनिया","Chilli & coriander","मिरची व कोथिंबीर"],["बिलोना मथानी","Bilona churning","बिलोना रवी"],["सफेद पनीर","White paneer","पांढरे पनीर"],["कांच बोतलें","Glass bottles","काचेच्या बाटल्या"],["हरा चारागाह","Green pasture","हिरवे कुरण"],["गुणवत्ता टेस्ट","Quality test","गुणवत्ता चाचणी"],["वेजी बास्केट","Veggie basket","भाज्यांची बास्केट"],
// ---- चैटबॉट ----
["राम-राम {0} जी! 🙏 मैं 'आज की धार' का AI मित्र हूँ। दूध, ऑर्डर, वॉलेट, डिलीवरी या कोई भी समस्या हो तो बेझिझक पूछें।","Hello {0}! 🙏 I'm the Aaj Ki Dhar AI buddy. Ask me anything about milk, orders, wallet, delivery or any problem.","नमस्कार {0}! 🙏 मी 'आज की धार' चा AI मित्र आहे. दूध, ऑर्डर, वॉलेट, डिलिव्हरी किंवा कोणतीही समस्या असेल तर बिनधास्त विचारा."],
["राम-राम सा! 🙏 मैं 'आज की धार' का AI सहायक हूँ। दूध, डिलीवरी, पेमेंट, वॉलेट या कोई भी समस्या हो तो पूछें। लॉगिन / साइन-अप के लिए प्रोफ़ाइल बटन या {A0}।","Hello! 🙏 I'm the Aaj Ki Dhar AI assistant. Ask me about milk, delivery, payment, wallet or any problem. To log in / sign up, use the Profile button or {A0}.","नमस्कार! 🙏 मी 'आज की धार' चा AI सहाय्यक आहे. दूध, डिलिव्हरी, पेमेंट, वॉलेट किंवा कोणतीही समस्या असेल तर विचारा. लॉग इन / साइन-अपसाठी प्रोफाइल बटण किंवा {A0}."],
["यहाँ दबाएं","tap here","येथे दाबा"],["WhatsApp पर मालिक से बात करें","Talk to the owner on WhatsApp","WhatsApp वर मालकाशी बोला"],
["😔 असुविधा के लिए क्षमा करें। तुरंत समाधान: • सुबह 9:00 बजे तक बताने पर उस दिन की पूरी राशि वॉलेट में वापस क्रेडिट या नया रिप्लेसमेंट मिलेगा। • डिलीवरी न आई हो तो राशि वापस या अगली सुबह एक्स्ट्रा डिलीवरी। जल्दी समाधान के लिए: {A0}","😔 Sorry for the inconvenience.<br><strong>Instant resolution:</strong><br>• Tell us by 9:00 AM and the full amount for that day is credited back to your wallet, or you get a replacement.<br>• If a delivery didn't arrive, you get a refund or an extra delivery next morning.<br>For a quick fix: {A0}","😔 झालेल्या गैरसोयीबद्दल क्षमस्व.<br><strong>त्वरित उपाय:</strong><br>• सकाळी 9:00 पर्यंत कळवल्यास त्या दिवसाची पूर्ण रक्कम वॉलेटमध्ये परत मिळेल किंवा नवीन रिप्लेसमेंट मिळेल.<br>• डिलिव्हरी न आल्यास रक्कम परत किंवा दुसऱ्या सकाळी एक्स्ट्रा डिलिव्हरी.<br>लवकर उपायासाठी: {A0}"],
["😔 असुविधा के लिए क्षमा करें। तुरंत समाधान: • सुबह 9:00 बजे तक बताने पर उस दिन की पूरी राशि वॉलेट में वापस क्रेडिट या नया रिप्लेसमेंट मिलेगा। • डिलीवरी न आई हो तो राशि वापस या अगली सुबह एक्स्ट्रा डिलीवरी। आपकी शिकायत मालिक को भेज दी गई है। जल्दी समाधान के लिए: {A0}","😔 Sorry for the inconvenience.<br><strong>Instant resolution:</strong><br>• Tell us by 9:00 AM and the full amount for that day is credited back to your wallet, or you get a replacement.<br>• If a delivery didn't arrive, you get a refund or an extra delivery next morning.<br>Your complaint has been sent to the owner. For a quick fix: {A0}","😔 झालेल्या गैरसोयीबद्दल क्षमस्व.<br><strong>त्वरित उपाय:</strong><br>• सकाळी 9:00 पर्यंत कळवल्यास त्या दिवसाची पूर्ण रक्कम वॉलेटमध्ये परत मिळेल किंवा नवीन रिप्लेसमेंट मिळेल.<br>• डिलिव्हरी न आल्यास रक्कम परत किंवा दुसऱ्या सकाळी एक्स्ट्रा डिलिव्हरी.<br>तुमची तक्रार मालकाला पाठवली आहे. लवकर उपायासाठी: {A0}"],
["💸 रिफंड: गुणवत्ता में कमी हो तो सुबह 9 बजे तक बताएं, पूरी राशि वॉलेट में लौटा दी जाएगी। वॉलेट का बचा बैलेंस बैंक में भी ट्रांसफर करवा सकते हैं ({A0})।","💸 <strong>Refund:</strong> If there is any quality issue, tell us by 9 AM and the full amount is returned to your wallet. You can also get your remaining wallet balance transferred to your bank ({A0}).","💸 <strong>रिफंड:</strong> गुणवत्तेत कमतरता असल्यास सकाळी 9 पर्यंत कळवा, पूर्ण रक्कम वॉलेटमध्ये परत केली जाईल. वॉलेटची उरलेली रक्कम बँकेतही ट्रान्सफर करता येते ({A0})."],
["👛 आपका वॉलेट बैलेंस ₹{0} है। ऊपर 'वॉलेट' पर टैप करके UPI/QR से रिचार्ज करें और 12 अंकों का UTR डालें; सत्यापन होते ही पैसे जुड़ जाते हैं।","👛 Your wallet balance is <strong>₹{0}</strong>. Tap 'Wallet' at the top, recharge via UPI/QR and enter the 12-digit UTR; the money is added once verified.","👛 तुमचा वॉलेट बॅलन्स <strong>₹{0}</strong> आहे. वरील 'वॉलेट' वर टॅप करून UPI/QR ने रिचार्ज करा आणि 12 अंकी UTR टाका; पडताळणी होताच पैसे जमा होतात."],
["👛 वॉलेट रिचार्ज के लिए पहले लॉगिन करें। फिर UPI/QR से भुगतान करके UTR डालें; सत्यापन के बाद पैसे वॉलेट में जुड़ते हैं।","👛 Log in first to recharge the wallet. Then pay via UPI/QR and enter the UTR; the money is added after verification.","👛 वॉलेट रिचार्जसाठी आधी लॉग इन करा. मग UPI/QR ने पेमेंट करून UTR टाका; पडताळणीनंतर पैसे वॉलेटमध्ये जमा होतात."],
["💳 अभी उपलब्ध भुगतान: {0}। ऑर्डर पर 'ऑर्डर' बटन दबाकर अपनी पसंद चुनें।","💳 Payment options available now: <strong>{0}</strong>. Tap the 'Order' button and choose what suits you.","💳 सध्या उपलब्ध पेमेंट: <strong>{0}</strong>. 'ऑर्डर' बटण दाबून तुमची पसंती निवडा."],
["कृपया WhatsApp पर संपर्क करें","Please contact us on WhatsApp","कृपया WhatsApp वर संपर्क करा"],
["🚚 डिलीवरी रोज़ सुबह 5:30 – 7:00 AM (या लेट स्लॉट 7:00 – 8:30 AM)। ऑर्डर का कट-ऑफ रात 10:00 बजे है। स्लॉट व डोरबेल की पसंद होम स्क्रीन पर चुन सकते हैं।","🚚 Delivery every morning <strong>5:30 – 7:00 AM</strong> (or late slot 7:00 – 8:30 AM). The order cut-off is 10:00 PM. You can choose the slot and doorbell preference on the home screen.","🚚 डिलिव्हरी रोज सकाळी <strong>5:30 – 7:00 AM</strong> (किंवा उशिराचा स्लॉट 7:00 – 8:30 AM). ऑर्डरचा कट-ऑफ रात्री 10:00 आहे. स्लॉट व घंटीची निवड होम स्क्रीनवर करता येते."],
["⏸ कल का दूध रोकने के लिए रात 10 बजे से पहले 'कल के लिए Pause' दबाएं; लंबी यात्रा के लिए 'लंबी छुट्टी' में तारीखें चुनें। रुकी हुई डिलीवरी का पैसा नहीं कटता।","⏸ To stop tomorrow's milk, tap 'Pause for tomorrow' before 10 PM; for a long trip choose dates in 'Long holiday'. You are not charged for paused deliveries.","⏸ उद्याचे दूध थांबवण्यासाठी रात्री 10 पूर्वी 'उद्यासाठी Pause' दाबा; लांबच्या प्रवासासाठी 'दीर्घ सुट्टी' मध्ये तारखा निवडा. थांबवलेल्या डिलिव्हरीचे पैसे कापले जात नाहीत."],
["📅 'सब्सक्रिप्शन' में आइटम व मात्रा चुनें। तारीखें (कितने दिन के लिए) चुनें; उतने दिन का पैसा एडवांस वॉलेट से लिया जाता है। बैलेंस कम हो तो पहले रिचार्ज का विकल्प दिखता है।","📅 In 'Subscription', choose items and quantities, then pick the dates (how many days). The amount for those days is taken in advance from your wallet. If the balance is low, you are offered a recharge first.","📅 'सबस्क्रिप्शन' मध्ये आयटम व प्रमाण निवडा. तारखा (किती दिवसांसाठी) निवडा; तितक्या दिवसांचे पैसे आधी वॉलेटमधून घेतले जातात. बॅलन्स कमी असल्यास आधी रिचार्जचा पर्याय दिसतो."],
["🏷 आज के रेट:","🏷 Today's rates:","🏷 आजचे दर:"],["(स्टॉक खत्म)","(out of stock)","(स्टॉक संपला)"],
["🥛 गिर गाय का दूध: फैट {0}%, SNF {1}% 🐃 मुर्राह भैंस का दूध: फैट {2}%, SNF {3}% कच्चा अनपाश्चुरीकृत दूध 4 AM मिल्किंग के बाद तुरंत डिलीवर होता है।","🥛 Gir cow milk: Fat {0}%, SNF {1}%<br>🐃 Murrah buffalo milk: Fat {2}%, SNF {3}%<br>Raw unpasteurised milk is delivered right after the 4 AM milking.","🥛 गीर गायीचे दूध: फॅट {0}%, SNF {1}%<br>🐃 मुर्राह म्हशीचे दूध: फॅट {2}%, SNF {3}%<br>कच्चे अपाश्चराइज्ड दूध 4 AM च्या दूध काढण्यानंतर लगेच डिलिव्हर होते."],
["🧀 हमारा पनीर रोज़ ताजे दूध से नींबू द्वारा तैयार, बिना स्टार्च का कच्चा सफेद पनीर है। गिर गाय, भैंस और डाइट लो-फैट तीन वैरायटी उपलब्ध हैं।","🧀 Our paneer is raw white paneer made daily from fresh milk using lemon, with no starch. Three varieties are available: Gir cow, buffalo and diet low-fat.","🧀 आमचे पनीर रोज ताज्या दुधापासून लिंबाने बनवलेले, स्टार्च नसलेले कच्चे पांढरे पनीर आहे. गीर गाय, म्हैस आणि डाएट लो-फॅट असे तीन प्रकार उपलब्ध आहेत."],
["🧈 गिर गाय का वैदिक बिलोना घी (कांच जार) और मुर्राह भैंस का दानेदार घी (टिन) उपलब्ध है। दोनों पारंपरिक मथानी विधि से बनते हैं।","🧈 Gir cow Vedic bilona ghee (glass jar) and Murrah buffalo granular ghee (tin) are available. Both are made by the traditional churning method.","🧈 गीर गायीचे वैदिक बिलोना तूप (काचेची बरणी) आणि मुर्राह म्हशीचे दाणेदार तूप (डबा) उपलब्ध आहे. दोन्ही पारंपरिक रवी पद्धतीने बनतात."],
["🥬 खेत की ताजी पालक-मेथी, देसी टमाटर, हरी मिर्च-धनिया और 2 किग्रा की ग्रीन वेजी बास्केट रोज़ की ताजा कटाई से मिलती है।","🥬 Fresh spinach-fenugreek, desi tomatoes, green chilli-coriander and a 2 kg green veggie basket, all from the day's fresh harvest.","🥬 शेतातील ताजी पालक-मेथी, देशी टोमॅटो, हिरवी मिरची-कोथिंबीर आणि 2 किलोची ग्रीन भाजी बास्केट रोजच्या ताज्या कापणीतून मिळते."],
["🌿 हमारा फार्म जमवारामगढ़ घाटी और सिरसी रोड, जयपुर में है, जहाँ गायें खुले में चरती हैं।","🌿 Our farm is in <strong>Jamwaramgarh Ghati</strong> and <strong>Sirsi Road, Jaipur</strong>, where the cows graze in the open.","🌿 आमचा फार्म <strong>जमवारामगढ घाटी</strong> आणि <strong>सिरसी रोड, जयपूर</strong> येथे आहे, जिथे गायी मोकळ्या चरतात."],
["🍼 दूध कांच की बोतल में आता है। अगली सुबह डिलीवरी बॉय को खाली धुली बोतल लौटा दें।","🍼 Milk comes in a glass bottle. Hand the empty, washed bottle back to the delivery person the next morning.","🍼 दूध काचेच्या बाटलीत येते. दुसऱ्या सकाळी डिलिव्हरी बॉयला रिकामी धुतलेली बाटली परत द्या."],
["📦 होम स्क्रीन पर किसी भी प्रोडक्ट के 'ऑर्डर' बटन से मात्रा (+/−) और भुगतान का तरीका चुनकर ऑर्डर करें। रोज़ के दूध के लिए 'सब्सक्रिप्शन' लें। ऑर्डर का कट-ऑफ रात 10 बजे है।","📦 On the home screen, tap a product's 'Order' button, choose quantity (+/−) and payment method, and order. For daily milk, take a 'Subscription'. Order cut-off is 10 PM.","📦 होम स्क्रीनवर कोणत्याही प्रॉडक्टच्या 'ऑर्डर' बटणाने प्रमाण (+/−) व पेमेंटचा पर्याय निवडून ऑर्डर करा. रोजच्या दुधासाठी 'सबस्क्रिप्शन' घ्या. ऑर्डरचा कट-ऑफ रात्री 10 आहे."],
["👤 आप लॉगिन हैं। प्रोफ़ाइल (नीचे) में जानकारी अपडेट या लॉग आउट कर सकते हैं।","👤 You are logged in. You can update your details or log out from Profile (below).","👤 तुम्ही लॉग इन आहात. प्रोफाइलमध्ये (खाली) माहिती अपडेट किंवा लॉग आउट करता येईल."],
["🔐 लॉगिन/साइन-अप के लिए {A0}; आपके ईमेल पर OTP आएगा।","🔐 To log in / sign up, {A0}; an OTP will come to your email.","🔐 लॉग इन/साइन-अपसाठी {A0}; तुमच्या ईमेलवर OTP येईल."],
["☎️ {A0} या ईमेल: {0}","☎️ {A0} or email: {0}","☎️ {A0} किंवा ईमेल: {0}"],
["आपका स्वागत है! 🙏 कुछ और पूछना हो तो बताइए।","You're welcome! 🙏 Ask me if you need anything else.","तुमचे स्वागत आहे! 🙏 आणखी काही विचारायचे असेल तर सांगा."],
["राम-राम सा! 🙏 बताइए, क्या मदद करूँ?","Hello! 🙏 How can I help?","नमस्कार! 🙏 सांगा, कशी मदत करू?"],
["मैं आपकी बात पूरी तरह समझ नहीं पाया 🙏 आप दूध, रेट, डिलीवरी, पेमेंट, वॉलेट, पॉज या शिकायत के बारे में पूछ सकते हैं, या सीधे {A0}।","I couldn't fully understand 🙏 You can ask about milk, rates, delivery, payment, wallet, pause or a complaint, or reach us directly: {A0}.","मला तुमचे बोलणे पूर्ण समजले नाही 🙏 तुम्ही दूध, दर, डिलिव्हरी, पेमेंट, वॉलेट, पॉज किंवा तक्रारीबद्दल विचारू शकता, किंवा थेट {A0}."],
// ---- सर्वर संदेश ----
["पहले अपना खाता पूरा करें।","Please complete your account first.","कृपया आधी तुमचे खाते पूर्ण करा."],
["कृपया सही विवरण भरें।","Please fill in valid details.","कृपया योग्य तपशील भरा."],
["शुरू की तारीख कल या उसके बाद की हो।","The start date must be tomorrow or later.","सुरुवातीची तारीख उद्या किंवा नंतरची असावी."],
["अंतिम तारीख शुरू की तारीख से पहले नहीं हो सकती।","The end date cannot be before the start date.","शेवटची तारीख सुरुवातीच्या तारखेपूर्वी असू शकत नाही."],
["सब्सक्रिप्शन अधिकतम 62 दिन का हो सकता है।","A subscription can be at most 62 days.","सबस्क्रिप्शन कमाल 62 दिवसांचे असू शकते."],
["कृपया कम से कम 1 आइटम चुनें।","Please select at least 1 item.","कृपया किमान 1 आयटम निवडा."],
["वॉलेट में ₹{0} कम हैं। पहले रिचार्ज करें।","₹{0} short in wallet. Please recharge first.","वॉलेटमध्ये ₹{0} कमी आहेत. आधी रिचार्ज करा."],
["कोई सक्रिय सब्सक्रिप्शन नहीं है।","There is no active subscription.","कोणतेही सक्रिय सबस्क्रिप्शन नाही."]
]);
window.I18N._html({
  footer_about: {
    en: 'Our natural dairy farm is located in <strong>Jamwaramgarh Ghati</strong> and <strong>Sirsi Road, Jaipur</strong>. Our Gir cows and Murrah buffaloes are fed only lush organic fodder, and milk is filled straight into glass bottles at Brahma Muhurta (4:00 AM) and delivered to your door by 5:30.',
    mr: 'आमचा नैसर्गिक डेअरी फार्म <strong>जमवारामगढ घाटी</strong> आणि <strong>सिरसी रोड, जयपूर</strong> येथे आहे. येथील गीर गायी व मुर्राह म्हशींना फक्त हिरवा सेंद्रिय चारा दिला जातो आणि ब्रह्ममुहूर्तावर (4:00 AM) थेट काचेच्या बाटल्यांत भरून 5:30 वाजता तुमच्या दारापर्यंत पोहोचवले जाते.'
  }
});
window.I18N._pol({
  refund: {
    en: { title: "Refund & return policy", body: "<strong>100% satisfaction guarantee:</strong><br><br>1. If the taste or quality of the milk seems off on any day, report it by 9:00 AM and the full amount for that day is credited back to your wallet immediately.<br><br>2. If a basket or vegetables turn out bad, you get an immediate replacement or refund.<br><br>3. Any remaining wallet balance can be transferred back to your original bank account whenever you wish." },
    mr: { title: "रिफंड व रिटर्न धोरण", body: "<strong>100% समाधान हमी:</strong><br><br>1. एखाद्या दिवशी दुधाची चव किंवा गुणवत्ता योग्य न वाटल्यास सकाळी 9:00 पर्यंत कळवा; त्या दिवसाची पूर्ण रक्कम लगेच तुमच्या वॉलेटमध्ये परत जमा केली जाईल.<br><br>2. बास्केट किंवा भाजी खराब निघाल्यास त्वरित रिप्लेसमेंट किंवा रिफंड मिळेल.<br><br>3. वॉलेटमधील उरलेली रक्कम ग्राहक हवे तेव्हा आपल्या मूळ बँक खात्यात ट्रान्सफर करून घेऊ शकतो." }
  },
  terms: {
    en: { title: "Terms & Conditions", body: "<strong>Daily service rules:</strong><br><br>1. <strong>Delivery time:</strong> Direct delivery between 5:30 AM and 7:00 AM.<br><br>2. <strong>Tomorrow's holiday (Pause):</strong> Before 10:00 PM, tap the Pause button in the app to stop the next day's milk.<br><br>3. <strong>Glass bottles:</strong> The empty, washed glass bottle must be handed back to the delivery person the next morning." },
    mr: { title: "नियम व अटी", body: "<strong>दैनंदिन सेवेचे नियम:</strong><br><br>1. <strong>डिलिव्हरीची वेळ:</strong> सकाळी 5:30 AM ते 7:00 AM दरम्यान थेट डिलिव्हरी होईल.<br><br>2. <strong>उद्याची सुट्टी (Pause):</strong> रात्री 10:00 पूर्वी ॲपमधील पॉज बटण दाबून पुढील दिवसाचे दूध थांबवता येते.<br><br>3. <strong>काचेच्या बाटल्या:</strong> दुसऱ्या सकाळी डिलिव्हरी बॉयला मागची रिकामी काचेची बाटली धुऊन परत देणे बंधनकारक आहे." }
  }
});
