/* base guard (v11.58) — KEEP FIRST: this file must never run without app-base.js. If it is missing, it is loaded and this file runs again. Source: addons/all/a1158-base-guard.js */
if(!(typeof nfAhwStaff=="function"||window.__NF_OWNTAB__||window.nfQuietNotices))throw(function(){var t=window.__NF_BASEGUARD__=window.__NF_BASEGUARD__||{n:0,k:0,t0:Date.now(),log:[],gate:!1};t.n++;var o=document.currentScript,c=document.querySelector("script[data-nf-appbase]"),g=function(e){return String(e).replace(/[?&]nf[hr]=\d+/g,"")},m=function(e,n){return e+(e.indexOf("?")<0?"?":"&")+n},s=g(o&&o.getAttribute("src")||t.app||"./app.js");t.app=s;var u=g(c&&c.getAttribute("src")||"./app-base.js?v=bd72e734eb"),h=function(){try{return!!(typeof nfAhwStaff=="function"||window.__NF_OWNTAB__||window.nfQuietNotices)}catch{return!1}};try{localStorage.setItem("nf.baseheal",JSON.stringify({at:new Date().toISOString(),n:t.n,tag:!!c,app:s}))}catch{}if(t.n===1&&o&&!o.async&&!o.defer&&document.readyState==="loading"){t.log.push("write"),document.write('<script src="'+(c?m(u,"nfh=1"):u)+'"><\/script><script src="'+s+'"><\/script>');return}if(!t.busy){t.busy=!0,t.gate=!0,t.log.push("retry");try{!t.gated&&typeof Store=="object"&&Store&&(t.gated=!0,["save","remove"].forEach(function(e){var n=Store[e];typeof n=="function"&&(Store[e]=function(){return t.gate?(t.held=(t.held||0)+1,Promise.resolve(null)):n.apply(this,arguments)})}))}catch{}var i=!1;try{i=/^en/.test(localStorage.getItem("nf.lang")||localStorage.getItem("nf.lang.stu")||"")}catch{}var r=null,f=null,l=function(e){try{if(!r){r=document.createElement("div"),r.id="nf-baseguard",r.setAttribute("dir",i?"ltr":"rtl"),r.setAttribute("style",'position:fixed;top:0;right:0;bottom:0;left:0;z-index:2147483647;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;padding:24px;background:#12161a;color:#f3f1ea;font:16px/1.7 system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif;text-align:center'),f=document.createElement("div"),r.appendChild(f);var n=document.createElement("button");n.type="button",n.textContent=i?"Reload now":"\u062D\u0645\u0651\u0644 \u062A\u0627\u0646\u064A \u062F\u0644\u0648\u0642\u062A\u064A",n.setAttribute("style","font:inherit;padding:10px 22px;border-radius:999px;border:0;background:#f3f1ea;color:#12161a;cursor:pointer"),n.onclick=function(){try{location.replace(location.pathname+"?nfr="+Date.now()+location.hash)}catch{location.reload()}},r.appendChild(n),(document.body||document.documentElement).appendChild(r)}f.textContent=e?i?"Weak connection \u2014 the rest of the system is still loading. Trying again by itself.":"\u0627\u0644\u0646\u062A \u0636\u0639\u064A\u0641 \u2014 \u0628\u0627\u0642\u064A \u0627\u0644\u0633\u064A\u0633\u062A\u0645 \u0644\u0633\u0647 \u0628\u064A\u062D\u0645\u0651\u0644. \u0628\u0646\u062D\u0627\u0648\u0644 \u062A\u0627\u0646\u064A \u0644\u0648\u062D\u062F\u0646\u0627.":i?"Loading the rest of the system\u2026":"\u0628\u0646\u062D\u0645\u0651\u0644 \u0628\u0627\u0642\u064A \u0627\u0644\u0633\u064A\u0633\u062A\u0645\u2026"}catch{}},y=function(e,n,p){var a=document.createElement("script");a.src=e,a.async=!1,a.onload=n,a.onerror=function(){try{a.remove()}catch{}p()},(document.head||document.documentElement).appendChild(a)},v=function(){l(!0),setTimeout(b,Math.min(3e4,2e3*t.k))},d=function(){y(s,function(){t.log.push("app");try{r&&r.remove()}catch{}try{typeof render=="function"&&render(!0)}catch{}},function(){l(!0),setTimeout(d,Math.min(3e4,2e3*++t.k))})},b=function(){if(t.k++,h())return t.gate=!1,t.log.push("base"),d();y(m(u,"nfr="+Date.now()),function(){if(!h())return v();t.gate=!1,t.log.push("base"),d()},v)};l(!1),b()}})(),new Error("nf: app-base.js was not loaded \u2014 loading it first (base guard)");
/* Ninety Fabrication — app.js = add-ons added after 13 Nov 2026.
   Everything older lives in app-base.js, which index.html loads just before this file (core.js -> app-base.js -> app.js).
   app-base.js is only downloaded again when it changes, so: append new add-ons HERE, and touch app-base.js only to patch old code
   (then its ?v=b<sha1[:9]> in index.html and sw.js must change too). See claude/deploy-status.md. */

/* v11.52 (المصنع بس) — «مين اتشاف فين» #/faces (المالك بس): «▶ التسجيل» على كل التقاط
   محمود 13/11 17:05 «اوك»: الالتقاطات اللي اتجابت من جهاز التسجيل نفسه (من غير صورة) بتظهر في الصفحة، ودوسة على أي التقاط بتشغّل
   تسجيل الكاميرا عند اللحظة دي جوه الأبليكيشن (من 10 ثواني قبلها لـ 30 بعدها، بمشغّل هيك فيجن — نفس مشغّل «الكاميرات لايف»).
   - الصفحة هي هي (اليوم · الكاميرا · تحديث كل 30 ثانية · دوسة على الصورة تكبّرها) + زرار «▶ التسجيل» + علامة «نفس المكان ×N»
     على الالتقاطات اللي اتكررت في نفس البقعة (غالبًا حاجة ثابتة مش شخص) + «اخفي المتكرر».
   - المشغّل: تقريب على مكان الوش (×3 / ×6 وسحب بالصباع)، مربع أصفر مكان الالتقاط، وقّف/كمّل، من الأول. بيقفل بـ× أو Escape أو لما تسيب الصفحة.
   - التوكن بييجي من Edge `hikez` (rec) للمالك بس وبيفضل في الذاكرة بس. مفيش صلاحية اتغيّرت.
   الكود القديم للصفحة (a1129 في app-base.js) زي ما هو؛ الإضافة دي بتركّب صفحة جديدة مكانه. */
;(function () {
  if (window.__NF_FACES2__ || typeof EXTRA_VIEWS === "undefined" || !EXTRA_VIEWS.faces) return;
  if ((typeof isStudioz === "function" && isStudioz()) || (typeof isConstruction === "function" && isConstruction())) return;
  window.__NF_FACES2__ = 1;
  const EN = () => typeof I18N !== "undefined" && I18N.lang === "en";
  const T = (a, b) => (EN() ? b : a);
  const H = (s) => (typeof esc === "function" ? esc(String(s == null ? "" : s)) : String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]));
  const can = () => !!(S && S.sb && S.sb.from) && typeof isAdmin === "function" && isAdmin() && !S.viewOrig && !S.demoOrig;
  const CFG = { before: 10, after: 30, slow: 30000, repMin: 4, repNear: 0.02, mainW: 3200, zooms: [1, 3, 6] };
  const EZ_SRC = "https://cdn.jsdelivr.net/npm/ezuikit-js@9.0.26/ezuikit.js", EZ_STATIC = "https://cdn.jsdelivr.net/npm/ezuikit-js@9.0.26/ezuikit_static"; // the same player (and the same copy in the phone's memory) as «الكاميرات لايف»
  const st = { day: "", cam: "", rows: null, urls: {}, busy: false, err: "", timer: null, at: 0, noRep: false };
  const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
  const hm = (iso) => { try { return new Date(iso).toLocaleTimeString(EN() ? "en-GB" : "ar-EG", { hour: "numeric", minute: "2-digit" }); } catch (e) { return ""; } };
  const hms = (iso) => { try { return new Date(iso).toLocaleString(EN() ? "en-GB" : "ar-EG", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit", second: "2-digit" }); } catch (e) { return ""; } };
  // the recorder keeps its own clock (Cairo): its time as "YYYY-MM-DD HH:MM:SS", whatever clock the phone is on
  const cairo = (iso, addSec) => {
    const p = {}; new Intl.DateTimeFormat("en-GB", { timeZone: "Africa/Cairo", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" })
      .formatToParts(new Date(new Date(iso).getTime() + addSec * 1000)).forEach((x) => { p[x.type] = x.value; });
    return `${p.year}-${p.month}-${p.day} ${p.hour === "24" ? "00" : p.hour}:${p.minute}:${p.second}`;
  };
  const rectOf = (r) => { const q = r && r.rect; if (!q) return null; const x = Number(q.x), y = Number(q.y), w = Number(q.w), h = Number(q.h); return [x, y, w, h].every((n) => isFinite(n) && n >= 0 && n <= 1) && w > 0 && h > 0 ? { x, y, w, h } : null; };

  function css() {
    if (document.getElementById("nffaces2-css")) return;
    const s = document.createElement("style"); s.id = "nffaces2-css";
    s.textContent = `.nfface button.ph{border:0;cursor:pointer;flex-direction:column;gap:6px;font:inherit;font-size:12px;color:#ddd;width:100%}
.nfface button.ph .f2pl{width:44px;height:44px;border-radius:50%;background:rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center;font-size:18px;color:#fff;padding-inline-start:3px}
.nfface .f2rep{font-size:11px;color:#a86400;background:rgba(240,170,0,.14);border-radius:6px;padding:2px 6px;align-self:flex-start}
.nfface .f2rec{width:100%;justify-content:center}
#nfrecv{position:fixed;inset:0;z-index:100000;background:#000;display:flex;flex-direction:column;color:#fff}
#nfrecv .rv-bar{display:flex;align-items:center;gap:10px;padding:calc(10px + env(safe-area-inset-top)) 14px 8px;font-size:14px}
#nfrecv .rv-bar .rv-cap{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;opacity:.92}
#nfrecv .rv-x{width:40px;height:40px;border-radius:50%;border:0;background:rgba(255,255,255,.16);color:#fff;font-size:22px;line-height:40px;cursor:pointer;flex:none}
#nfrecv .rv-stage{flex:1;min-height:0;display:flex;align-items:center;justify-content:center;overflow:hidden}
#nfrecv .rv-vid{position:relative;overflow:hidden;background:#111;touch-action:manipulation}
#nfrecv .rv-vid.rv-zoomed{touch-action:none;cursor:grab}
#nfrecv .rv-lay{position:absolute;left:0;top:0;width:100%;height:100%;transform-origin:0 0;will-change:transform}
#nfrecv .rv-lay.rv-glide{transition:transform .25s ease-out}
#nfrecv .rv-pl{position:absolute;inset:0}
#nfrecv .rv-mk{position:absolute;box-sizing:border-box;border:calc(2px / var(--z,1)) solid #ffd400;border-radius:calc(4px / var(--z,1));pointer-events:none;box-shadow:0 0 0 calc(1px / var(--z,1)) rgba(0,0,0,.55)}
#nfrecv .rv-msg{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;text-align:center;padding:16px;font-size:14px;background:rgba(0,0,0,.45)}
#nfrecv .rv-msg:empty{display:none}
#nfrecv .rv-msg small{opacity:.7;font-size:11px;direction:ltr}
#nfrecv .rv-ctl{display:flex;gap:8px;flex-wrap:wrap;justify-content:center;padding:10px 12px 4px}
#nfrecv .rv-ctl button,#nfrecv .rv-msg button{border:0;border-radius:999px;padding:9px 14px;font:inherit;font-size:13px;background:rgba(255,255,255,.16);color:#fff;cursor:pointer}
#nfrecv .rv-ctl button.on{background:#ffd400;color:#000}
#nfrecv .rv-ctl button[disabled]{opacity:.4}
#nfrecv .rv-note{padding:4px 14px calc(12px + env(safe-area-inset-bottom));font-size:12px;opacity:.7;text-align:center}
@media (orientation:landscape) and (max-height:520px){#nfrecv .rv-note{display:none}#nfrecv .rv-bar{padding-top:6px;padding-bottom:4px}#nfrecv .rv-ctl{padding:6px 12px}}`;
    document.head.appendChild(s);
  }

  /* ---------------- the page ---------------- */
  function tagRep(rows) { // a capture whose place on the picture repeats many times on the same camera that day = most likely a fixed thing, not a person
    const g = rows.map((r) => ({ r, q: rectOf(r) })).filter((x) => x.q);
    rows.forEach((r) => { r._rep = 0; });
    g.forEach((a) => { a.r._rep = g.filter((b) => (b.r.cam_id || "") === (a.r.cam_id || "") && Math.abs(b.q.x - a.q.x) < CFG.repNear && Math.abs(b.q.y - a.q.y) < CFG.repNear).length; });
  }
  const isRep = (r) => (r._rep || 0) >= CFG.repMin;
  async function load() {
    if (!can() || st.busy) return; st.busy = true;
    const day = st.day || today();
    const a = new Date(day + "T00:00:00"), b = new Date(a.getTime() + 86400000);
    try {
      const { data, error } = await S.sb.from("hik_events").select("id,happened_at,event_type,cam_id,cam_name,human_name,similarity,pic_path,pic_state,worker_id,rect:raw->rect").gte("happened_at", a.toISOString()).lt("happened_at", b.toISOString()).order("happened_at", { ascending: false }).limit(300);
      if (error) throw error;
      st.rows = data || []; st.err = ""; st.at = Date.now(); tagRep(st.rows);
      const need = st.rows.map((r) => r.pic_path).filter((p) => p && !st.urls[p]);
      if (need.length) {
        const { data: su } = await S.sb.storage.from("hikfaces").createSignedUrls(need.slice(0, 300), 3600);
        (su || []).forEach((x) => { if (x && x.signedUrl && x.path) st.urls[x.path] = x.signedUrl; });
      }
    } catch (e) { st.err = String((e && e.message) || e || "").slice(0, 120); if (!st.rows) st.rows = []; }
    finally { st.busy = false; }
    paint();
  }
  const wname = (r) => {
    if (r.worker_id && typeof byId === "function") { const w = byId("workers", r.worker_id); if (w && w.name) return w.name; }
    return r.human_name || "";
  };
  const shown = () => { let rows = st.rows || []; if (st.cam) rows = rows.filter((r) => (r.cam_name || "") === st.cam); if (st.noRep) rows = rows.filter((r) => !isRep(r)); return rows; };
  function listHtml() {
    if (!st.rows) return `<div class="muted small">${H(T("بنجيب الالتقاطات…", "Loading captures…"))}</div>`;
    if (st.err) return `<div class="banner warn"><span>${H(T("تعذّر التحميل: ", "Could not load: ") + st.err)}</span></div>`;
    const all = st.cam ? st.rows.filter((r) => (r.cam_name || "") === st.cam) : st.rows, rows = shown(), nRep = all.filter(isRep).length;
    if (!all.length) return `<div class="banner info"><span>${H(T("لسه مفيش وشوش اتسجلت في اليوم ده. الكاميرا اللي بتلتقط الوشوش دلوقتي: المدخل (main entranc login).", "No faces recorded on this day yet. The camera capturing faces right now: the entrance (main entranc login)."))}</span></div>`;
    const cnt = T(`${all.length} التقاط`, `${all.length} captures`) + (nRep ? T(` — ${nRep} منهم في نفس المكان بالظبط (غالبًا حاجة ثابتة مش شخص)`, ` — ${nRep} of them at exactly the same spot (most likely a fixed thing, not a person)`) : "");
    return `<div class="small muted" style="margin:2px 0 8px">${H(cnt)}</div><div class="nffaces">${rows.map((r) => {
      const u = r.pic_path && st.urls[r.pic_path]; const n = wname(r); const rec = !!(r.cam_id && r.happened_at);
      const ph = u ? `<div class="ph" style="background-image:url('${H(u)}')"></div>`
        : r.pic_state === "pending" ? `<div class="ph">${H(T("الصورة جاية…", "Picture coming…"))}</div>`
        : rec ? `<button type="button" class="ph" data-f2rec="${H(r.id)}"><span class="f2pl">▶</span><span>${H(T("شوف التسجيل", "Watch the recording"))}</span></button>`
        : `<div class="ph">${H(T("مفيش صورة", "No picture"))}</div>`;
      return `<div class="card nfface">${ph}<div class="who notr" dir="auto">${n ? H(n) + (r.similarity ? ` <span class="muted small">${H(Math.round(Number(r.similarity) * (Number(r.similarity) <= 1 ? 100 : 1)))}%</span>` : "") : `<span class="muted">${H(T("مش معروف لسه", "Not known yet"))}</span>`}</div><div class="meta"><span class="notr" dir="auto">${H(r.cam_name || "")}</span><span>${H(hm(r.happened_at))}</span></div>${isRep(r) ? `<div class="f2rep">${H(T(`نفس المكان ×${r._rep}`, `Same spot ×${r._rep}`))}</div>` : ""}${rec && u ? `<button type="button" class="btn sm f2rec" data-f2rec="${H(r.id)}"><span>▶ ${H(T("التسجيل", "Recording"))}</span></button>` : ""}</div>`;
    }).join("")}</div>`;
  }
  function barHtml() {
    const cams = st.rows ? [...new Set(st.rows.map((r) => r.cam_name || "").filter(Boolean))] : [];
    const nRep = st.rows ? (st.cam ? st.rows.filter((r) => (r.cam_name || "") === st.cam) : st.rows).filter(isRep).length : 0;
    return `<div class="nffbar"><input type="date" class="input" data-f2day value="${H(st.day || today())}" max="${H(today())}" style="max-width:170px">
      <button type="button" class="chip ${!st.cam ? "on" : ""}" data-f2cam="">${H(T("كل الكاميرات", "All cameras"))}</button>${cams.map((c) => `<button type="button" class="chip notr ${st.cam === c ? "on" : ""}" data-f2cam="${H(c)}">${H(c)}</button>`).join("")}
      ${nRep || st.noRep ? `<button type="button" class="chip ${st.noRep ? "on" : ""}" data-f2rep aria-pressed="${st.noRep ? "true" : "false"}">${H(T("اخفي المتكرر", "Hide repeated spots"))}</button>` : ""}
      <button type="button" class="btn sm" data-f2refresh>${typeof icon === "function" ? icon("refresh") : ""}<span>${H(T("تحديث", "Refresh"))}</span></button></div>`;
  }
  function paint() {
    const b = document.getElementById("nff2bar"), l = document.getElementById("nff2list");
    if (b) b.innerHTML = barHtml(); if (l) l.innerHTML = listHtml();
  }
  EXTRA_VIEWS.faces = () => {
    if (!can()) return `<div class="card"><p class="small ink2">${H(T("الصفحة دي للمالك بس.", "This page is for the owner only."))}</p></div>`;
    css();
    setTimeout(() => { if (!st.rows || Date.now() - st.at > 20000) load(); else paint(); }, 30);
    clearInterval(st.timer); st.timer = setInterval(() => { if (!/^#\/faces(\/|$)/.test(location.hash) || document.hidden || R.o) return; if ((st.day || today()) === today()) load(); }, 30000);
    return `<div class="stack"><div class="small ink2">${H(T("كل التقاط للكاميرا بيظهر هنا بوقته. دوس «▶ التسجيل» تشوف الفيديو عند اللحظة دي، ودوس على الصورة تكبّرها. لما نسمّي الناس، الاسم هيظهر تحت الصورة.", "Every capture shows here with its time. Tap “▶ Recording” to watch the video at that moment, and tap a picture to see it big. Once people are named, the name shows under the picture."))}</div><div id="nff2bar">${barHtml()}</div><div id="nff2list">${listHtml()}</div></div>`;
  };

  /* ---------------- the recording player ---------------- */
  const R = { o: null, pl: null, row: null, seq: 0, w: 0, h: 0, zi: 0, tx: 0, ty: 0, mark: true, started: false, paused: false, t0: 0, slow: null, drag: null };
  let ezP = null;
  const loadEz = () => (window.EZUIKit && window.EZUIKit.EZUIKitPlayer) ? Promise.resolve(window.EZUIKit) : (ezP = ezP || new Promise((ok, no) => {
    const sc = document.createElement("script"); sc.src = EZ_SRC; sc.async = true;
    sc.onload = () => (window.EZUIKit && window.EZUIKit.EZUIKitPlayer ? ok(window.EZUIKit) : (ezP = null, no(new Error("ez")))); sc.onerror = () => { ezP = null; no(new Error("ez")); };
    document.head.appendChild(sc);
  }));
  async function camOf(id) { // the camera's recorder (serial) — from the cameras page's list, else asked once
    const pick = (l) => (Array.isArray(l) ? l.find((c) => c && c.id === id && c.serial) : null) || null;
    let c = null;
    try { c = pick(window.__nfCamWall && window.__nfCamWall.st && window.__nfCamWall.st.cams); } catch (e) {}
    if (!c) { try { const j = JSON.parse(localStorage.getItem("nf_camlist") || "null"); c = pick(j && j.cams); } catch (e) {} }
    if (!c) { try { const x = await S.sb.functions.invoke("hik", { body: { action: "cameras" } }); c = pick(x && x.data && x.data.cameras); } catch (e) {} }
    return c;
  }
  async function recInfo(row) {
    const c = await camOf(row.cam_id); if (!c) return { ok: false, err: "nocam" };
    let r = null, er = "";
    try { const x = await S.sb.functions.invoke("hikez", { body: { id: row.cam_id, serial: c.serial, rec: true, begin: cairo(row.happened_at, -CFG.before), end: cairo(row.happened_at, CFG.after) } }); r = x && x.data; if (!r && x && x.error) er = "server"; } catch (e) { er = "net"; }
    if (!r || !r.ok || !r.token || !/^ezopen:\/\/.+\.rec(\?|$)/.test(String(r.url || ""))) return { ok: false, err: String((r && (r.err || r.code)) || er || "info") };
    return { ok: true, token: r.token, domain: r.domain, url: r.url };
  }
  const tele = (ok, why) => { // one health line in the server log (counts only): did the recording open on the phone, and how fast
    try { const x = S.sb.functions.invoke("hiktele", { body: { v: "11.52", dev: window.matchMedia && window.matchMedia("(pointer:coarse)").matches ? "phone" : "pc", mode: "rec", eng: "ez", ezOpen: 1, ezOk: ok ? 1 : 0, ezFail: ok ? 0 : 1, ezTtffMed: ok ? Date.now() - R.t0 : null, ezErr: ok ? "" : String(why || "") } }); if (x && x.catch) x.catch(() => {}); } catch (e) {}
  };
  const q = (sel) => (R.o ? R.o.querySelector(sel) : null);
  function msg(html) { const m = q(".rv-msg"); if (m) m.innerHTML = html || ""; }
  function kill() {
    clearTimeout(R.slow); const pl = R.pl; R.pl = null;
    const old = q(".rv-pl"); if (old) { const n = document.createElement("div"); n.className = "rv-pl"; old.style.display = "none"; old.parentNode.insertBefore(n, old); const done = () => { try { old.remove(); } catch (e) {} };
      try { const d = pl && (typeof pl.destroy === "function" ? pl.destroy() : typeof pl.stop === "function" ? pl.stop() : null); if (d && d.then) { d.then(done, done); setTimeout(done, 2500); } else done(); } catch (e) { done(); } }
  }
  function size() {
    const sg = q(".rv-stage"), v = q(".rv-vid"); if (!sg || !v) return;
    const aw = sg.clientWidth, ah = sg.clientHeight; if (!aw || !ah) return;
    const W = Math.floor(Math.min(aw, ah * 16 / 9)), Hh = Math.floor(W * 9 / 16);
    if (W === R.w && Hh === R.h) return;
    R.w = W; R.h = Hh; v.style.width = W + "px"; v.style.height = Hh + "px";
    try { if (R.pl) { if (typeof R.pl.resize === "function") R.pl.resize(W, Hh); else if (typeof R.pl.reSize === "function") R.pl.reSize(W, Hh); } } catch (e) {}
    zoomTo(R.zi, true);
  }
  const clampT = () => { const z = CFG.zooms[R.zi]; R.tx = Math.min(0, Math.max(R.w - R.w * z, R.tx)); R.ty = Math.min(0, Math.max(R.h - R.h * z, R.ty)); };
  function applyT(glide) {
    const l = q(".rv-lay"), v = q(".rv-vid"); if (!l) return; const z = CFG.zooms[R.zi];
    l.classList.toggle("rv-glide", !!glide); l.style.setProperty("--z", String(z)); l.style.transform = `translate(${R.tx}px,${R.ty}px) scale(${z})`;
    if (v) v.classList.toggle("rv-zoomed", z > 1);
  }
  function zoomTo(i, quiet) { // bigger around the place of the face (the middle of the picture when the place is not known)
    R.zi = i; const z = CFG.zooms[i], rc = rectOf(R.row), cx = rc ? rc.x + rc.w / 2 : 0.5, cy = rc ? rc.y + rc.h / 2 : 0.5;
    R.tx = R.w / 2 - cx * R.w * z; R.ty = R.h / 2 - cy * R.h * z; clampT(); applyT(!quiet); btns();
  }
  function btns() {
    const z = CFG.zooms[R.zi], b = (k) => q(`[data-rv="${k}"]`);
    const zb = b("zoom"); if (zb) { zb.classList.toggle("on", z > 1); zb.querySelector("span").textContent = z > 1 ? T(`مقرّب ×${z}`, `Zoomed ×${z}`) : (rectOf(R.row) ? T("قرّب على الوش", "Zoom on the face") : T("قرّب", "Zoom in")); }
    const pb = b("pause"); if (pb) { const okp = !!(R.pl && R.started && typeof R.pl.pause === "function" && (typeof R.pl.resume === "function" || typeof R.pl.play === "function")); pb.disabled = !okp; pb.querySelector("span").textContent = R.paused ? T("▶ كمّل", "▶ Resume") : T("⏸ وقّف", "⏸ Pause"); }
    const mb = b("mark"); if (mb) mb.classList.toggle("on", R.mark);
    const mk = q(".rv-mk"); if (mk) mk.style.display = R.mark ? "" : "none";
  }
  function fail(why) {
    if (!R.o) return; clearTimeout(R.slow); tele(false, why);
    const code = String(why || "").replace(/[^A-Za-z0-9 _:.-]/g, "").slice(0, 40);
    const t = why === "nocam" ? T("مش لاقي الكاميرا دي في جهاز التسجيل.", "This camera was not found on the recorder.")
      : why === "lib" ? T("المشغّل مانزلش — النت ضعيف؟", "The player did not download — weak internet?")
      : why === "slow" ? T("التسجيل اتأخر قوي. نت المصنع ممكن يكون واقف، أو مفيش تسجيل محفوظ للوقت ده.", "The recording is taking too long. The factory internet may be down, or nothing was recorded at that time.")
      : T("التسجيل مش راضي يفتح. ممكن مفيش تسجيل محفوظ للوقت ده أو نت المصنع واقف.", "The recording would not open. Maybe nothing was recorded at that time, or the factory internet is down.");
    kill(); R.started = false;
    msg(`<span>${H(t)}</span><button type="button" data-rv="again">${H(T("جرّب تاني", "Try again"))}</button><small>${H(code)}</small>`); btns();
  }
  async function start() {
    if (!R.o) return; const my = ++R.seq, row = R.row; kill(); R.started = false; R.paused = false; R.t0 = Date.now();
    msg(`<span>${H(T("بنجيب التسجيل من المصنع…", "Getting the recording from the factory…"))}</span>`); btns();
    R.slow = setTimeout(() => { if (my === R.seq && R.o && !R.started) fail("slow"); }, CFG.slow);
    const got = await Promise.all([loadEz().catch(() => null), recInfo(row).catch(() => ({ ok: false, err: "info" }))]);
    if (my !== R.seq || !R.o) return;
    const lib = got[0], info = got[1];
    if (!lib) return fail("lib"); if (!info || !info.ok) return fail((info && info.err) || "info");
    const inr = q(".rv-pl"); if (!inr) return; inr.id = "nfrecpl" + my;
    try {
      const E = lib.EZUIKitPlayer, d = Math.min(3, Math.max(1, window.devicePixelRatio || 1));
      R.pl = new E({ id: inr.id, accessToken: info.token, url: info.url, width: R.w || 320, height: R.h || 180, dpr: Math.round(Math.max(d, Math.min(8, CFG.mainW / Math.max(1, R.w))) * 100) / 100, template: "simple", audio: false, language: "en", dblClickFullscreen: false,
        env: { domain: info.domain }, staticPath: EZ_STATIC, loggerOptions: { level: "ERROR" },
        handleSuccess: () => {}, handleError: (e) => { if (my !== R.seq || R.started) return; let c = ""; try { c = [e && e.type, e && e.retcode, e && e.code, e && e.data && e.data.nErrorCode, e && e.msg].filter((x) => x != null && x !== "").join(":"); } catch (x) {} fail("err:" + c); } });
      const pl = R.pl, on = (name, fn) => { try { if (typeof pl.on === "function") pl.on(name, fn); else if (pl.eventEmitter && typeof pl.eventEmitter.on === "function") pl.eventEmitter.on(name, fn); } catch (e) {} };
      on((E.EVENTS && E.EVENTS.firstFrameDisplay) || "firstFrameDisplay", () => { if (my !== R.seq || R.started) return; R.started = true; clearTimeout(R.slow); msg(""); tele(true); btns(); });
    } catch (e) { fail("ctor"); }
  }
  function closeRec() {
    if (!R.o) return; R.seq++; kill(); const o = R.o; R.o = null; R.row = null; R.drag = null;
    try { o.remove(); } catch (e) {}
    document.removeEventListener("keydown", onKey, true); window.removeEventListener("resize", size);
  }
  function onKey(e) { if (e.key === "Escape") { e.preventDefault(); closeRec(); } }
  function openRec(row) {
    if (!row || !can()) return; css(); closeRec();
    const o = document.createElement("div"); o.id = "nfrecv"; o.setAttribute("role", "dialog"); o.setAttribute("aria-modal", "true"); o.dir = EN() ? "ltr" : "rtl";
    const rc = rectOf(row), who = wname(row);
    const mk = rc ? `<div class="rv-mk" style="left:${((rc.x - rc.w * 0.5) * 100).toFixed(3)}%;top:${((rc.y - rc.h * 0.5) * 100).toFixed(3)}%;width:${(rc.w * 200).toFixed(3)}%;height:${(rc.h * 200).toFixed(3)}%"></div>` : "";
    o.innerHTML = `<div class="rv-bar"><span class="rv-cap notr" dir="auto">${H([who, row.cam_name, hms(row.happened_at)].filter(Boolean).join(" · "))}</span><button type="button" class="rv-x" data-rv="x" aria-label="${H(T("قفل", "Close"))}">×</button></div>
      <div class="rv-stage"><div class="rv-vid" dir="ltr"><div class="rv-lay"><div class="rv-pl"></div>${mk}</div><div class="rv-msg"></div></div></div>
      <div class="rv-ctl"><button type="button" data-rv="pause" disabled><span></span></button><button type="button" data-rv="zoom"><span></span></button>${rc ? `<button type="button" data-rv="mark"><span>${H(T("المربع الأصفر", "Yellow box"))}</span></button>` : ""}<button type="button" data-rv="again"><span>${H(T("↻ من الأول", "↻ From the start"))}</span></button></div>
      <div class="rv-note">${H(rc ? T(`المقطع ${CFG.before + CFG.after} ثانية: الالتقاط حصل بعد حوالي ${CFG.before} ثواني من أوله، والمربع الأصفر مكان الوش ساعتها. كل تشغيل بياخد حوالي 25 ميجا من باقة نت المصنع.`, `The clip is ${CFG.before + CFG.after} seconds: the capture happened about ${CFG.before} seconds in, and the yellow box is where the face was. Each play uses about 25 MB of the factory's internet bundle.`) : T(`المقطع ${CFG.before + CFG.after} ثانية والالتقاط حصل بعد حوالي ${CFG.before} ثواني من أوله. كل تشغيل بياخد حوالي 25 ميجا من باقة نت المصنع.`, `The clip is ${CFG.before + CFG.after} seconds and the capture happened about ${CFG.before} seconds in. Each play uses about 25 MB of the factory's internet bundle.`))}</div>`;
    document.body.appendChild(o);
    R.o = o; R.row = row; R.w = R.h = 0; R.zi = 0; R.tx = R.ty = 0; R.mark = true;
    document.addEventListener("keydown", onKey, true); window.addEventListener("resize", size);
    const v = o.querySelector(".rv-vid"); // drag the zoomed picture around
    v.addEventListener("pointerdown", (e) => { if (CFG.zooms[R.zi] <= 1 || (e.target && e.target.closest && e.target.closest("button"))) return; R.drag = { id: e.pointerId, x: e.clientX, y: e.clientY, tx: R.tx, ty: R.ty }; try { v.setPointerCapture(e.pointerId); } catch (x) {} });
    v.addEventListener("pointermove", (e) => { const d = R.drag; if (!d || d.id !== e.pointerId) return; R.tx = d.tx + (e.clientX - d.x); R.ty = d.ty + (e.clientY - d.y); clampT(); applyT(false); });
    const up = (e) => { if (R.drag && R.drag.id === e.pointerId) R.drag = null; }; v.addEventListener("pointerup", up); v.addEventListener("pointercancel", up);
    size(); btns(); start();
  }
  function onCtl(k) {
    if (k === "x") return closeRec();
    if (k === "again") return start();
    if (k === "zoom") return zoomTo((R.zi + 1) % CFG.zooms.length);
    if (k === "mark") { R.mark = !R.mark; return btns(); }
    if (k === "pause") {
      const pl = R.pl; if (!pl || !R.started) return;
      try { const d = R.paused ? (typeof pl.resume === "function" ? pl.resume() : pl.play()) : pl.pause(); if (d && d.catch) d.catch(() => {}); R.paused = !R.paused; } catch (e) {}
      return btns();
    }
  }

  document.addEventListener("click", (ev) => {
    const t = ev.target && ev.target.closest ? ev.target : null; if (!t) return;
    const rv = t.closest("#nfrecv [data-rv]"); if (rv) { ev.preventDefault(); if (!rv.disabled) onCtl(rv.getAttribute("data-rv")); return; }
    const rb = t.closest("[data-f2rec]"); if (rb) { ev.preventDefault(); const id = rb.getAttribute("data-f2rec"); const row = (st.rows || []).find((r) => String(r.id) === id); if (row) openRec(row); return; }
    const c = t.closest("[data-f2cam]"); if (c) { ev.preventDefault(); st.cam = c.getAttribute("data-f2cam") || ""; paint(); return; }
    if (t.closest("[data-f2rep]")) { ev.preventDefault(); st.noRep = !st.noRep; paint(); return; }
    if (t.closest("[data-f2refresh]")) { ev.preventDefault(); load(); }
  });
  document.addEventListener("change", (ev) => {
    const t = ev.target; if (!t || !t.matches || !t.matches("[data-f2day]")) return;
    st.day = t.value || today(); st.rows = null; st.cam = ""; st.noRep = false; paint(); load();
  });
  window.addEventListener("hashchange", closeRec);
  window.__nfFaces2 = { st, R, CFG, openRec, closeRec, load, paint, cairo, zoomTo }; // for tests
})();
;(function(){if(window.__NF_A1152__||(window.__NF_A1152__=1,typeof isStuSys=="function"&&isStuSys()||typeof isConstruction=="function"&&isConstruction()))return;const p={penHeld:0,penApplied:0,penDropped:0,attBlocked:0,logSkipped:0},m={AGE:5*6e4,ATT_N:4,ATT_MS:10*6e4};if(typeof applyAutoPenalties=="function"&&typeof computeAutoPenalties=="function"){const s=new Map;let y=0;const c=n=>(+n.days||0)+"|"+(+n.minutes||0),A=(n,e,t,o)=>{o.add(n);const a=s.get(n);return a&&a.sig===e?t-a.t>=m.AGE?(s.delete(n),p.penApplied++,!0):(p.penHeld++,!1):(s.set(n,{sig:e,t}),p.penHeld++,!1)};applyAutoPenalties=(n=>async function(e,t){if(y)return n.apply(this,arguments);let o=0,a=0;const u=Date.now(),g=new Set;for(const r of t||[]){const l=computeAutoPenalties(r,e),_=new Set(l.map(i=>i.id));for(const i of l){const d=byId("penalties",i.id);d&&(d.status==="waived"||d.edited)||d&&+d.days==+i.days&&+d.minutes==+i.minutes||A("s:"+i.id,c(i),u,g)&&(await Store.save("penalties",Object.assign({},d||{},i),{silent:!0}),o++)}for(const i of list("penalties"))i.auto&&i.workerId===r.id&&i.month===e&&!_.has(i.id)&&i.status!=="waived"&&!i.edited&&A("r:"+i.id,"x",u,g)&&(await Store.remove("penalties",i.id),a++)}const w=e+"_",f=new Set((t||[]).map(r=>r.id));if(s.forEach((r,l)=>{if(g.has(l))return;const _=l.slice(2);if(!_.startsWith(w))return;const i=_.slice(w.length);for(const d of f)if(i.startsWith(d+"_")){s.delete(l),p.penDropped++;return}}),o||a)try{rerender()}catch{}return{created:o,removed:a}})(applyAutoPenalties),typeof ACTIONS=="object"&&typeof ACTIONS.penAuto=="function"&&(ACTIONS.penAuto=(n=>async function(){y++;try{return await n.apply(this,arguments)}finally{y--}})(ACTIONS.penAuto));let h=!1;try{typeof RENDER_HOOKS!="undefined"&&RENDER_HOOKS.push(()=>{h||!S.session||(h=!0,setTimeout(()=>{try{typeof window.nfPenAutoRun=="function"&&window.nfPenAutoRun(!0)}catch{}},m.AGE+5e4))})}catch{}window.nfPenCalm={seen:s,manual:()=>y}}if(typeof setAtt=="function"){const s=new Map,y=/At$|^queued|^updated/,c=e=>Array.isArray(e)?"["+e.map(c).join(",")+"]":e&&typeof e=="object"?"{"+Object.keys(e).filter(t=>!y.test(t)).sort().map(t=>t+":"+c(e[t])).join(",")+"}":JSON.stringify(e===void 0?null:e);let A=0;const h=(e,t)=>{try{return c((attendanceFor(e)||{})[t.id]||null)}catch{return""}},n=(e,t)=>(s.get(e)||[]).filter(o=>t-o.t<m.ATT_MS);setAtt=(e=>function(t,o,a){let u=null,g="";try{if(t&&o&&o.id&&a&&typeof a=="object"){u=t+"|"+o.id,g=c(a);const f=Date.now(),r=n(u,f).filter(l=>l.sig===g);if(r.length>=m.ATT_N&&h(t,o)!==r[r.length-1].after){p.attBlocked++;try{console.warn("nf: attendance row saved "+r.length+" times in 10 min and still coming back \u2014 held",u)}catch{}if(f-A>6e4){A=f;try{toast(typeof I18N!="undefined"&&I18N.lang==="en"?"This row was saved several times and keeps changing back \u2014 another device is changing it. Refresh both devices.":"\u0627\u0644\u0633\u0637\u0631 \u062F\u0647 \u0627\u062A\u062D\u0641\u0638 \u0643\u0630\u0627 \u0645\u0631\u0629 \u0648\u0644\u0633\u0647 \u0628\u064A\u0631\u062C\u0639 \u2014 \u0641\u064A\u0647 \u062C\u0647\u0627\u0632 \u062A\u0627\u0646\u064A \u0628\u064A\u063A\u064A\u0651\u0631\u0647. \u0627\u0639\u0645\u0644 \u062A\u062D\u062F\u064A\u062B \u0644\u0644\u062C\u0647\u0627\u0632\u064A\u0646.","err")}catch{}}return Promise.resolve()}}}catch{u=null}const w=e.apply(this,arguments);return u&&Promise.resolve(w).then(()=>{try{const f=Date.now(),r=n(u,f);r.push({sig:g,t:f,after:h(t,o)}),s.set(u,r),s.size>400&&s.delete(s.keys().next().value)}catch{}},()=>{}),w})(setAtt)}if(typeof logChange=="function"){const s={live:1,track:1};logChange=(y=>function(c,A,h,n){try{if(c==="driverpos"||c==="dict")return p.logSkipped++,Promise.resolve();if(c==="trips"&&h==="update"&&Array.isArray(n)){const e=n.filter(t=>!["updatedAt","updatedBy"].includes(t));if(e.length&&e.every(t=>s[t]))return p.logSkipped++,Promise.resolve()}}catch{}return y.apply(this,arguments)})(logChange)}window.nfCalmWrites={stats:()=>Object.assign({},p),cfg:m}})();
;(function(){if(window.__NF_SIDENOW__)return;window.__NF_SIDENOW__=1;try{typeof RENDER_HOOKS!="undefined"&&RENDER_HOOKS.push(function(){try{typeof i18nToggleUI=="function"&&i18nToggleUI()}catch(e){}try{window.nfSideStripNow&&window.nfSideStripNow()}catch(e){}try{window.nfHomeTogNow&&window.nfHomeTogNow()}catch(e){}try{window.nfFabDialNow&&window.nfFabDialNow()}catch(e){}})}catch(e){}})();

/* v11.54 (المصنع بس) — «كمبيوتر التحليل» #/vision (المالك بس)
   محمود 13/11 17:05 «ابتدي بقى السيستم اللي هنحطه على الكمبيوتر» + 17:57 «كمل»: الصفحة اللي بيتربط منها كمبيوتر تحليل الكاميرات اللي في المصنع.
   - «اربط كمبيوتر جديد»: الأمر اللي بيتكتب على الكمبيوتر (نسخ) + خانة الكود اللي بيظهر على شاشته + «وافق واربط» (Edge `vision` approve).
   - حالة كل كمبيوتر: شغال دلوقتي / آخر اتصال، البروسيسور والرام وكارت الشاشة وحرارته، البرنامج اللي شغال عليه، عنوانه، وأجهزة الفيديو اللي لقاها على الشبكة + «شيله».
   - صفحة جديدة للمالك بس؛ مفيش صلاحية اتغيّرت لحد. الكمبيوتر هو اللي بيكلّم السيستم (مفيش حاجة مفتوحة على شبكة المصنع). */
;(function () {
  if (window.__NF_VISION__ || typeof EXTRA_VIEWS === "undefined" || typeof NAV === "undefined") return;
  if ((typeof isStudioz === "function" && isStudioz()) || (typeof isConstruction === "function" && isConstruction())) return;
  window.__NF_VISION__ = 1;
  const EN = () => typeof I18N !== "undefined" && I18N.lang === "en";
  const T = (a, b) => (EN() ? b : a);
  const H = (s) => (typeof esc === "function" ? esc(String(s == null ? "" : s)) : String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]));
  const can = () => !!(S && S.sb && S.sb.functions) && typeof isAdmin === "function" && isAdmin() && !S.viewOrig && !S.demoOrig;
  const CMD = 'curl -fsSL "https://erhcnkjyaumdoixkksbz.supabase.co/functions/v1/vision?a=install" | sudo bash';
  const st = { nodes: null, want: null, skew: 0, at: 0, err: "", busy: false, msg: "", ok: false, timer: null, rm: "", code: "", name: "" };

  if (typeof canSee === "function") canSee = ((f) => function (v) { return v === "vision" ? can() : f.apply(this, arguments); })(canSee);
  try {
    if (Array.isArray(NAV) && !NAV.some((n) => n && n.id === "vision")) {
      const item = { id: "vision", label: () => T("كمبيوتر التحليل", "Analysis computer"), icon: "monitor" };
      const i = NAV.findIndex((n) => n && n.id === "faces"), j = i >= 0 ? i + 1 : NAV.findIndex((n) => n && n.id === "settings");
      if (j >= 0) NAV.splice(j, 0, item); else NAV.push(item);
    }
  } catch (e) { console.warn("vision nav", e); }
  if (typeof EXTRA_TITLES !== "undefined") EXTRA_TITLES.vision = () => ({ title: T("كمبيوتر التحليل", "Analysis computer"), sub: T("كمبيوتر المصنع اللي بيحلّل الكاميرات — للمالك بس", "The factory computer that analyses the cameras — owner only") });
  try { // the app only opens pages that have a name in VIEW_TITLES (the lesson of v11.30)
    if (typeof VIEW_TITLES !== "undefined" && !VIEW_TITLES.vision) VIEW_TITLES.vision = "كمبيوتر التحليل";
    if (/^#\/vision(\/|$)/.test(location.hash) && typeof parseRoute === "function" && S && S.route && S.route.view !== "vision") { parseRoute(); if (typeof rerender === "function") rerender(); }
  } catch (e) { console.warn("vision route", e); }

  function css() {
    if (document.getElementById("nfvz-css")) return;
    const s = document.createElement("style"); s.id = "nfvz-css";
    s.textContent = `.nfvz-cmd{direction:ltr;text-align:left;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;background:rgba(0,0,0,.06);border-radius:8px;padding:10px;word-break:break-all;user-select:all;-webkit-user-select:all}
.nfvz-steps{margin:0;padding-inline-start:20px;display:flex;flex-direction:column;gap:8px;font-size:14px}
.nfvz-form{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.nfvz-form .nfvz-code{max-width:140px;font-size:20px;letter-spacing:3px;text-align:center;direction:ltr}
.nfvz-node{display:flex;flex-direction:column;gap:6px}
.nfvz-node .nfvz-h{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.nfvz-node .nfvz-h b{font-size:15px}
.nfvz-dot{width:10px;height:10px;border-radius:50%;background:#bbb;flex:none}.nfvz-dot.on{background:#1faa59}.nfvz-dot.off{background:#d9822b}.nfvz-dot.no{background:#d64545}
.nfvz-kv{display:grid;grid-template-columns:auto 1fr;gap:3px 12px;font-size:13px}.nfvz-kv span:nth-child(odd){color:var(--ink2,#666)}
.nfvz-kv .ltr{direction:ltr;text-align:start;unicode-bidi:plaintext}`;
    document.head.appendChild(s);
  }
  const ago = (ms) => {
    const s = Math.max(0, Math.round(ms / 1000));
    if (s < 90) return T("من ثواني", "seconds ago");
    const m = Math.round(s / 60); if (m < 90) return T(`من ${m} دقيقة`, `${m} min ago`);
    const h = Math.round(m / 60); if (h < 36) return T(`من ${h} ساعة`, `${h} h ago`);
    return T(`من ${Math.round(h / 24)} يوم`, `${Math.round(h / 24)} days ago`);
  };
  async function ask(body) { // → the function's answer, also when it answered with an error status
    try {
      const x = await S.sb.functions.invoke("vision", { body });
      if (x && x.data) return x.data;
      const c = x && x.error && x.error.context;
      if (c && typeof c.json === "function") { try { return await c.json(); } catch (e) {} }
      return { ok: false, err: "server" };
    } catch (e) { return { ok: false, err: "net" }; }
  }
  async function load() {
    if (!can() || st.busy) return; st.busy = true;
    const r = await ask({ a: "nodes" }); st.busy = false;
    if (r && r.ok) { st.nodes = r.nodes || []; st.want = r.want || null; st.skew = r.now ? Date.parse(r.now) - Date.now() : 0; st.err = ""; st.at = Date.now(); }
    else { st.err = String((r && (r.err || r.error)) || "server"); if (!st.nodes) st.nodes = []; }
    paint();
  }
  function nodeHtml(n) {
    const now = Date.now() + st.skew, seen = n.seen_at ? Date.parse(n.seen_at) : 0, live = n.status === "approved" && seen && now - seen < 200000;
    const h = n.health || {}, inf = n.info || {}, m = inf.machine || {}, g = (inf.graphics && inf.graphics.nvidia) || null, hg = h.gpu || null, ch = h.child || {};
    const dot = n.status === "revoked" ? "no" : n.status === "pending" ? "" : live ? "on" : "off";
    const state = n.status === "pending" ? T("مستني موافقتك — الكود ظاهر على شاشته", "Waiting for your approval — the code is on its screen")
      : n.status === "revoked" ? T("متشال", "Removed")
      : live ? T("شغال دلوقتي", "Online now") : (seen ? T("مش متصل — آخر اتصال ", "Offline — last seen ") + ago(now - seen) : T("لسه ما اتصلش", "Has not connected yet"));
    const rows = [];
    const cpu = m.cpu || inf.cpu; if (cpu) rows.push([T("البروسيسور", "Processor"), cpu + (m.threads || inf.cores ? ` · ${m.threads || inf.cores}` : ""), 1]);
    const ram = m.ram_mb || h.mem_total_mb; if (ram) rows.push([T("الرام", "Memory"), `${Math.round(ram / 1024)} GB` + (h.mem_free_mb != null ? T(` (فاضي ${Math.round(h.mem_free_mb / 1024)})`, ` (${Math.round(h.mem_free_mb / 1024)} free)`) : ""), 1]);
    if (hg || g) rows.push([T("كارت الشاشة", "Graphics card"), (hg ? hg.name : g.name) + (hg ? ` · ${hg.temp}°C · ${hg.util}%` : ""), 1]);
    else if (inf.graphics) rows.push([T("كارت الشاشة", "Graphics card"), T("لسه من غير تعريف — هيتسطّب من هنا", "Driver not installed yet — it will be installed from here"), 0]);
    if (h.disk_free_gb != null) rows.push([T("المساحة الفاضية", "Free disk"), `${Math.round(h.disk_free_gb)} GB`, 1]);
    if (m.os || inf.os) rows.push([T("النظام", "System"), m.os || inf.os, 1]);
    if (h.ip) rows.push([T("عنوانه على الشبكة", "Network address"), h.ip, 1]);
    if (n.status === "approved") rows.push([T("البرنامج", "Program"), (n.bundle_ver || T("لسه بينزل", "downloading")) + (n.bundle_ver ? (ch.running ? T(" · شغال", " · running") : T(" · واقف", " · stopped")) : "") + (st.want && n.bundle_ver && st.want !== n.bundle_ver ? T(` ← بيتحدّث لـ ${st.want}`, ` → updating to ${st.want}`) : ""), 0]);
    const rec = inf.network && Array.isArray(inf.network.recorder_like) ? inf.network.recorder_like : null;
    if (rec) rows.push([T("أجهزة فيديو على الشبكة", "Video devices on the network"), rec.length ? rec.slice(0, 12).map((d) => d.ip).join("  ") : T("مالقاش ولا جهاز — اتأكد إنه على سويتش الريكوردر", "none found — check it is on the recorder's switch"), rec.length ? 1 : 0]);
    const rm = n.status === "revoked" ? "" : st.rm === n.id
      ? `<button type="button" class="btn sm danger" data-vz="rm2" data-id="${H(n.id)}"><span>${H(T("متأكد؟ شيله", "Sure? Remove"))}</span></button><button type="button" class="btn sm" data-vz="rm0"><span>${H(T("لأ", "No"))}</span></button>`
      : `<button type="button" class="btn sm" data-vz="rm1" data-id="${H(n.id)}"><span>${H(n.status === "pending" ? T("ارفضه", "Reject") : T("شيله", "Remove"))}</span></button>`;
    return `<div class="card nfvz-node" data-node="${H(n.id)}"><div class="nfvz-h"><span class="nfvz-dot ${dot}"></span><b class="notr" dir="auto">${H(n.name || T("كمبيوتر من غير اسم", "Unnamed computer"))}</b><span class="small muted">${H(state)}</span><span style="flex:1"></span>${rm}</div>${rows.length ? `<div class="nfvz-kv">${rows.map((r) => `<span>${H(r[0])}</span><span class="${r[2] ? "ltr notr" : ""}">${H(r[1])}</span>`).join("")}</div>` : ""}</div>`;
  }
  function listHtml() {
    if (!st.nodes) return `<div class="muted small">${H(T("بنشوف الكمبيوترات…", "Checking computers…"))}</div>`;
    const err = st.err ? `<div class="banner warn"><span>${H(T("تعذّر التحميل: ", "Could not load: ") + st.err)}</span></div>` : "";
    if (!st.nodes.length) return err + `<div class="banner info"><span>${H(T("لسه مفيش كمبيوتر مربوط. اتبع الخطوات اللي فوق.", "No computer linked yet. Follow the steps above."))}</span></div>`;
    return err + st.nodes.map(nodeHtml).join("");
  }
  function paint() {
    const l = document.getElementById("nfvzlist"); if (l) l.innerHTML = listHtml();
    const m = document.getElementById("nfvzmsg"); if (m) { m.textContent = st.msg || ""; m.className = "small " + (st.msg ? (st.ok ? "ok" : "bad") : ""); m.style.color = st.msg ? (st.ok ? "#1a8a48" : "#c0392b") : ""; }
    const c = document.querySelector("[data-vzcode]"), n = document.querySelector("[data-vzname]");
    if (c && !c.value && st.code && document.activeElement !== c) c.value = st.code;
    if (n && !n.value && st.name && document.activeElement !== n) n.value = st.name;
  }
  EXTRA_VIEWS.vision = () => {
    if (!can()) return `<div class="card"><p class="small ink2">${H(T("الصفحة دي للمالك بس.", "This page is for the owner only."))}</p></div>`;
    css();
    setTimeout(() => { paint(); if (!st.nodes || Date.now() - st.at > 15000) load(); }, 30);
    clearInterval(st.timer); st.timer = setInterval(() => { if (!/^#\/vision(\/|$)/.test(location.hash) || document.hidden) return; load(); }, 20000);
    return `<div class="stack">
      <div class="card"><h3 style="margin:0 0 10px">${H(T("اربط كمبيوتر جديد", "Link a new computer"))}</h3>
        <ol class="nfvz-steps">
          <li>${H(T("الكمبيوتر يتوصل بكابل على نفس سويتش جهاز التسجيل، ويتسطّب عليه Ubuntu 24.04.", "Connect the computer by cable to the recorder's switch and install Ubuntu 24.04 on it."))}</li>
          <li>${H(T("اللي بيسطّب يفتح Terminal على الكمبيوتر ويكتب الأمر ده:", "Whoever installs it opens Terminal on the computer and types this command:"))}
            <div class="nfvz-cmd notr" id="nfvzcmd">${H(CMD)}</div>
            <button type="button" class="btn sm" data-vz="copy" style="margin-top:6px">${typeof icon === "function" ? icon("copy") : ""}<span>${H(T("انسخ الأمر", "Copy the command"))}</span></button></li>
          <li>${H(T("هيظهر على شاشة الكمبيوتر كود من 6 أرقام — اكتبه هنا:", "A 6-digit code appears on the computer's screen — type it here:"))}
            <div class="nfvz-form" style="margin-top:6px"><input class="input nfvz-code notr" data-vzcode inputmode="numeric" autocomplete="off" maxlength="7" placeholder="000000" aria-label="${H(T("الكود", "Code"))}">
              <input class="input" data-vzname maxlength="60" style="max-width:220px" placeholder="${H(T("اسم الكمبيوتر (مثلًا: كمبيوتر المصنع)", "Computer name (e.g. Factory computer)"))}" aria-label="${H(T("اسم الكمبيوتر", "Computer name"))}">
              <button type="button" class="btn primary" data-vz="approve"><span>${H(T("وافق واربط", "Approve and link"))}</span></button></div>
            <div id="nfvzmsg" class="small" style="margin-top:6px;min-height:18px"></div></li>
        </ol>
        <p class="small ink2" style="margin:10px 0 0">${H(T("الكمبيوتر اللي توافق عليه بياخد برنامجه وتحديثاته من السيستم وبينفّذها بتحكم كامل في الجهاز. ماتوافقش غير على كود ظاهر قدامك على شاشة الكمبيوتر نفسه.", "A computer you approve takes its program and updates from the system and runs them with full control of that machine. Only approve a code you can see on the computer's own screen."))}</p></div>
      <div id="nfvzlist"></div></div>`;
  };
  async function approve() {
    const c = document.querySelector("[data-vzcode]"), n = document.querySelector("[data-vzname]");
    const code = String((c && c.value) || "").replace(/\D/g, ""), name = String((n && n.value) || "").trim();
    if (code.length !== 6) { st.msg = T("الكود 6 أرقام — زي ما هو ظاهر على شاشة الكمبيوتر.", "The code is 6 digits — exactly as shown on the computer's screen."); st.ok = false; return paint(); }
    st.msg = T("بنربط…", "Linking…"); st.ok = true; paint();
    const r = await ask({ a: "approve", code, name: name || T("كمبيوتر المصنع", "Factory computer") });
    if (r && r.ok) { st.msg = T("اتربط ✓ — هيبدأ ينزّل برنامجه خلال دقيقة.", "Linked ✓ — it starts downloading its program within a minute."); st.ok = true; st.code = ""; st.name = ""; if (c) c.value = ""; if (n) n.value = ""; }
    else { st.ok = false; const e = String((r && (r.err || r.error)) || ""); st.msg = e === "no_such_code" ? T("مفيش كمبيوتر مستني بالكود ده — راجع الأرقام اللي على الشاشة.", "No computer is waiting with this code — check the digits on its screen.") : e === "net" ? T("النت واقف — جرّب تاني.", "No internet — try again.") : T("ماتربطش: ", "Not linked: ") + (e || "server"); }
    paint(); load();
  }
  async function remove(id) {
    st.rm = ""; const r = await ask({ a: "revoke", node: id });
    if (!(r && r.ok)) { st.msg = T("ماتشالش: ", "Not removed: ") + String((r && (r.err || r.error)) || "server"); st.ok = false; }
    paint(); load();
  }
  document.addEventListener("click", (ev) => {
    const b = ev.target && ev.target.closest ? ev.target.closest("[data-vz]") : null; if (!b) return;
    ev.preventDefault(); const k = b.getAttribute("data-vz");
    if (k === "approve") return void approve();
    if (k === "rm1") { st.rm = b.getAttribute("data-id") || ""; return paint(); }
    if (k === "rm0") { st.rm = ""; return paint(); }
    if (k === "rm2") return void remove(b.getAttribute("data-id") || "");
    if (k === "copy") {
      const done = (ok) => { const s = b.querySelector("span"); if (s) { s.textContent = ok ? T("اتنسخ ✓", "Copied ✓") : T("حدّد الأمر وانسخه بإيدك", "Select the command and copy it"); setTimeout(() => { s.textContent = T("انسخ الأمر", "Copy the command"); }, 2500); } };
      try { navigator.clipboard.writeText(CMD).then(() => done(true), () => done(false)); } catch (e) { done(false); }
    }
  });
  document.addEventListener("input", (ev) => {
    const t = ev.target; if (!t || !t.matches) return;
    if (t.matches("[data-vzcode]")) { st.code = t.value; if (st.msg && !st.ok) { st.msg = ""; paint(); } }
    else if (t.matches("[data-vzname]")) st.name = t.value;
  });
  window.__nfVision = { st, load, paint, CMD }; // for tests
})();
;(function(){if(window.__NF_TBMIN__)return;window.__NF_TBMIN__=1;const e=document.documentElement,n=window.matchMedia?window.matchMedia("(max-width:900px)"):{matches:!1};try{if(!(window.CSS&&CSS.supports&&CSS.supports("inset-inline-start","0")))return}catch{return}try{(document.head||e).insertAdjacentHTML("beforeend",`<style id="nf-tbmin">
@media (max-width:900px){
  @media (prefers-reduced-motion:no-preference){
    html.nf-tbm .tabbar{transition:left .26s cubic-bezier(.2,.8,.2,1),right .26s cubic-bezier(.2,.8,.2,1),height .2s ease,border-radius .2s ease,bottom .2s ease,padding .2s ease}
    html.nf-tbm .tabbar>a{transition:opacity .16s ease .06s}
    html.nf-tbmin .tabbar>a{transition:opacity .08s ease}
    html.nf-tbm .nfdial .nfd-main{transition:transform .22s ease,bottom .26s cubic-bezier(.2,.8,.2,1)}
  }
  /* the two round buttons are the same size on the same line: 54px, 11px from the bottom, 14px from their edge (\u0645\u062D\u0645\u0648\u062F: \xAB\u0627\u0644\u0627\u062A\u0646\u064A\u0646 \u0645\u0634 \u0639\u0644\u0649 \u0644\u0627\u064A\u0646 \u0648\u0627\u062D\u062F\xBB) */
  html.nf-tbm.nf-tbmin .nfdial .nfd-main{bottom:calc(11px + env(safe-area-inset-bottom,0px))!important;width:54px!important;height:54px!important;box-sizing:border-box!important}
  html.nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{box-sizing:border-box!important;height:54px!important;min-height:0!important;padding:0!important;border-radius:27px!important;bottom:calc(11px + env(safe-area-inset-bottom,0px))!important;border:1px solid var(--line)!important;box-shadow:0 10px 26px -12px rgba(20,30,50,.45)!important;overflow:hidden!important;cursor:pointer}
  html[dir=rtl].nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{inset-inline-start:14px!important;inset-inline-end:calc(100% - 68px)!important}
  html:not([dir=rtl]).nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{inset-inline-end:14px!important;inset-inline-start:calc(100% - 68px)!important}
  html.nf-tbmin .tabbar.tabbar>a{position:absolute!important;inset:0!important;margin:0!important;padding:0!important;opacity:0!important;pointer-events:none!important;border-radius:27px!important;flex:none!important}
  html.nf-tbmin .tabbar.tabbar>a.on,html.nf-tbmin.nf-tbmore .tabbar.tabbar>a[data-action="openside"]{opacity:1!important}
  html.nf-tbmin .tabbar.tabbar>a>span,html.nf-tbmin .tabbar.tabbar>a>.cnt{display:none!important}
  html.nf-tbmin .tabbar.tabbar>a>svg{width:24px!important;height:24px!important}
  /* the \xAB+\xBB button wears what the folded button wears (light look only \u2014 at night it stays Ninety steel blue) */
  html.nf-tbm.nf-tbx .nfdial .nfd-main{width:54px!important;height:54px!important;box-sizing:border-box!important}
  html.nf-tbm.nf-tbx .nfdial .nfd-main svg{width:24px!important;height:24px!important}
  /* on a page that has no tab of its own the folded button shows \xAB\u0627\u0644\u0645\u0632\u064A\u062F\xBB: it gets the same fill, so the two buttons always match */
  html.nf-tbx.nf-tbmin.nf-tbmore .tabbar.tabbar>a[data-action="openside"]{background:var(--nf-tbx-on)!important;color:var(--nf-tbx-fg)!important}
  html.nf-tbm.nf-tbx.nf-tbxl .nfdial .nfd-main{background:linear-gradient(var(--nf-tbx-on),var(--nf-tbx-on)),var(--nf-tbx-bg)!important;color:var(--nf-tbx-fg)!important;border:1px solid var(--line)!important;box-shadow:0 10px 26px -12px rgba(20,30,50,.45)!important}
}
</style>`)}catch{return}e.classList.add("nf-tbm");let o=!1,u=0,b=0,d=0,x=0,g=!1,y=0,v=0;const E=()=>document.querySelector(".tabbar"),L=()=>{try{const t=E();e.classList.toggle("nf-tbmore",!(t&&t.querySelector(":scope > a.on")))}catch{}};function a(t){t=!!t&&!!n.matches,b=0,d=0,t!==o&&(o=t,t&&L(),e.classList.toggle("nf-tbmin",t))}const O=()=>window.scrollY||e.scrollTop||0;function C(){x=0;const t=O(),r=t-u;if(u=t,!n.matches){o&&a(!1);return}if(t<56){a(!1);return}(g||Date.now()-y<1500)&&(r>0?(b+=r,d=0,b>24&&Date.now()-v>2500&&a(!0)):r<0&&(d-=r,b=0,d>40&&a(!1)))}window.addEventListener("scroll",()=>{x||(x=requestAnimationFrame(C))},{passive:!0});const m=()=>{y=Date.now()};window.addEventListener("touchstart",()=>{g=!0,m()},{passive:!0,capture:!0}),["touchend","touchcancel"].forEach(t=>window.addEventListener(t,()=>{g=!1,m()},{passive:!0,capture:!0})),window.addEventListener("wheel",m,{passive:!0,capture:!0}),window.addEventListener("keydown",t=>{/^(Arrow|Page|Home|End| $)/.test(t.key||"")&&m()},!0),document.addEventListener("click",t=>{!o||!(t.target&&t.target.closest&&t.target.closest(".tabbar"))||(t.preventDefault(),t.stopPropagation(),v=Date.now(),a(!1))},!0),window.addEventListener("hashchange",()=>{u=0,a(!1)});try{n.addEventListener?n.addEventListener("change",()=>a(!1)):n.addListener&&n.addListener(()=>a(!1))}catch{}try{typeof RENDER_HOOKS!="undefined"&&RENDER_HOOKS.push(()=>{o&&L()})}catch{}let c="";const S=t=>!!t&&t!=="transparent"&&!/^rgba\(\s*0\s*,\s*0\s*,\s*0\s*,\s*0\s*\)$/.test(t);function l(){try{const t=E();if(!t||!n.matches)return;const r=(e.getAttribute("data-theme")||"")+"|"+e.className.replace(/\bnf-tb\w*/g,"").replace(/\s+/g," ").trim()+"|"+(document.body?document.body.className:"");if(r===c&&e.classList.contains("nf-tbx"))return;let w=t.querySelector(":scope > a.on"),i=null;if(!w){const s=t.querySelector(":scope > a[href]")||t.querySelector(":scope > a");if(!s)return;i=s.cloneNode(!0),i.classList.add("on"),i.style.cssText="position:absolute!important;visibility:hidden!important;pointer-events:none!important",t.appendChild(i),w=i}const k=getComputedStyle(w),R=getComputedStyle(t),q=k.color,N=k.backgroundColor,f=R.backgroundColor;i&&i.remove(),e.style.setProperty("--nf-tbx-fg",q),e.style.setProperty("--nf-tbx-on",S(N)?N:"transparent"),e.style.setProperty("--nf-tbx-bg",S(f)?f:"var(--surface)");const h=/(\d+(?:\.\d+)?)[ ,]+(\d+(?:\.\d+)?)[ ,]+(\d+(?:\.\d+)?)/.exec(f||"");let T=!0;if(h){let s=+h[1],D=+h[2],M=+h[3];/^color\(/.test(f)&&(s*=255,D*=255,M*=255),T=.2126*s+.7152*D+.0722*M>140}e.classList.toggle("nf-tbxl",T),e.classList.add("nf-tbx"),c=r}catch{}}let _=0;const p=()=>{clearTimeout(_),_=setTimeout(l,80)};try{typeof RENDER_HOOKS!="undefined"&&RENDER_HOOKS.push(p)}catch{}try{new MutationObserver(p).observe(e,{attributes:!0,attributeFilter:["data-theme","class"]})}catch{}try{n.addEventListener&&n.addEventListener("change",p),window.matchMedia&&window.matchMedia("(prefers-color-scheme:dark)").addEventListener("change",()=>{c="",p()})}catch{}setTimeout(l,400),setTimeout(l,2500),window.nfTabbarMin={set:a,is:()=>o,paint:()=>{c="",l()}}})();

/* v11.55 (المصنع بس) — «توضيح» في صفحة الكاميرات (المالك بس): فلتر عرض على الصورة (إضاءة + تباين + ألوان) بدرجتين.
   محمود 13/11 19:13 «نعمل فلتر على الكاميرات عشان نحسّن الرؤية بألوان وتفاصيل واضحة». ده عرض على شاشتك بس: إعدادات الكاميرات المتثبّتة والتسجيل مابيتغيّروش. */
;(function () {
  if (window.__NF_CAMFX__ || typeof EXTRA_VIEWS === "undefined") return;
  if ((typeof isStudioz === "function" && isStudioz()) || (typeof isConstruction === "function" && isConstruction())) return;
  window.__NF_CAMFX__ = 1;
  const EN = () => typeof I18N !== "undefined" && I18N.lang === "en";
  const T = (a, b) => (EN() ? b : a);
  const LV = [["", ""], ["nfcw-fx1", "1"], ["nfcw-fx2", "2"]];
  let lv = 0; try { lv = Math.max(0, Math.min(2, Number(localStorage.getItem("nf_cam_fx")) || 0)); } catch (e) {}
  const s = document.createElement("style"); s.id = "nfcwfx-css";
  s.textContent = `.nfcw-fx1 .nfcw-box video,.nfcw-fx1 .nfcw-box .nfcw-ez{filter:brightness(1.25) contrast(1.12) saturate(1.3)}
.nfcw-fx2 .nfcw-box video,.nfcw-fx2 .nfcw-box .nfcw-ez{filter:brightness(1.6) contrast(1.22) saturate(1.5)}
.nfcw-fxb.on{background:#ffd400;color:#000;border-color:transparent}`;
  document.head.appendChild(s);
  const label = () => "🔆 " + (lv ? T("توضيح " + lv, "Enhance " + lv) : T("توضيح", "Enhance"));
  function apply() {
    const r = document.documentElement; r.classList.toggle("nfcw-fx1", lv === 1); r.classList.toggle("nfcw-fx2", lv === 2);
    const b = document.querySelector(".nfcw-fxb"); if (b) { b.textContent = label(); b.classList.toggle("on", lv > 0); b.setAttribute("aria-pressed", lv ? "true" : "false"); }
  }
  function mount() {
    if (!/^#\/cams(\/|$)/.test(location.hash)) return;
    const t = document.querySelector(".nfcw-tools"); if (!t || t.querySelector(".nfcw-fxb")) return;
    const b = document.createElement("button"); b.type = "button"; b.className = "chip nfcw-fxb"; b.title = T("توضيح الصورة على شاشتك بس — مابيغيّرش الكاميرا ولا التسجيل", "Enhances the picture on your screen only — the camera and the recording are not changed");
    t.appendChild(b); apply();
  }
  document.addEventListener("click", (ev) => {
    const b = ev.target && ev.target.closest ? ev.target.closest(".nfcw-fxb") : null; if (!b) return;
    ev.preventDefault(); ev.stopPropagation(); lv = (lv + 1) % 3; try { localStorage.setItem("nf_cam_fx", String(lv)); } catch (e) {} apply();
  }, true);
  setInterval(mount, 700); window.addEventListener("hashchange", () => setTimeout(mount, 60)); apply();
  window.__nfCamFx = { get lv() { return lv; }, mount, apply };
})();

/* v11.56 (المصنع بس، المالك بس) — «حركة العمالة» #/moves + «سمّيه» في «مين اتشاف فين»
   محمود 13/11 19:38 «ابدأ» (سيستم تتبع سمارت): - صفحة «حركة العمالة»: مين قدام أنهي كاميرا دلوقتي + خط يوم أي شخص (من جدول stays اللي بيملاه كمبيوتر التحليل).
   - زرار «سمّيه» على كل التقاط: تختار العامل ⇒ rpc vision_name ⇒ كل التقاطات ووقفات نفس المجهول تبقى باسمه، والكمبيوتر يعرفه بعدها.
   صفحة جديدة للمالك بس؛ مفيش صلاحية اتغيّرت لحد. */
;(function () {
  if (window.__NF_MOVES__ || typeof EXTRA_VIEWS === "undefined" || typeof NAV === "undefined") return;
  if ((typeof isStudioz === "function" && isStudioz()) || (typeof isConstruction === "function" && isConstruction())) return;
  window.__NF_MOVES__ = 1;
  const EN = () => typeof I18N !== "undefined" && I18N.lang === "en";
  const T = (a, b) => (EN() ? b : a);
  const H = (s) => (typeof esc === "function" ? esc(String(s == null ? "" : s)) : String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]));
  const can = () => !!(S && S.sb && S.sb.from) && typeof isAdmin === "function" && isAdmin() && !S.viewOrig && !S.demoOrig;
  const st = { day: "", rows: null, err: "", busy: false, at: 0, who: "", timer: null };
  const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
  const hm = (iso) => { try { return new Date(iso).toLocaleTimeString(EN() ? "en-GB" : "ar-EG", { hour: "numeric", minute: "2-digit" }); } catch (e) { return ""; } };
  const workers = () => { try { return (typeof list === "function" ? list("workers") : []).filter((w) => w && w.name && !w.leftAt); } catch (e) { return []; } };
  const nameOf = (label) => {
    const l = String(label || "");
    if (l.startsWith("w:")) { let w = null; try { w = typeof byId === "function" ? byId("workers", l.slice(2)) : null; } catch (e) {} return (w && w.name) || T("عامل", "Worker") + " " + l.slice(2); }
    if (l.startsWith("u:")) return T("مجهول ", "Unknown ") + l.slice(2);
    return T("من غير وش ", "No face ") + l.slice(2);
  };
  const dur = (a, b) => { const m = Math.max(0, Math.round((Date.parse(b) - Date.parse(a)) / 60000)); return m < 1 ? T("أقل من دقيقة", "under a minute") : m < 60 ? T(`${m} د`, `${m} min`) : T(`${Math.floor(m / 60)} س ${m % 60} د`, `${Math.floor(m / 60)} h ${m % 60} min`); };

  if (typeof canSee === "function") canSee = ((f) => function (v) { return v === "moves" ? can() : f.apply(this, arguments); })(canSee);
  try {
    if (Array.isArray(NAV) && !NAV.some((n) => n && n.id === "moves")) {
      const item = { id: "moves", label: () => T("حركة العمالة", "Staff movement"), icon: "map" };
      const i = NAV.findIndex((n) => n && n.id === "faces"), j = i >= 0 ? i + 1 : NAV.findIndex((n) => n && n.id === "settings");
      if (j >= 0) NAV.splice(j, 0, item); else NAV.push(item);
    }
    if (typeof VIEW_TITLES !== "undefined" && !VIEW_TITLES.moves) VIEW_TITLES.moves = "حركة العمالة";
    if (/^#\/moves(\/|$)/.test(location.hash) && typeof parseRoute === "function" && S && S.route && S.route.view !== "moves") { parseRoute(); if (typeof rerender === "function") rerender(); }
  } catch (e) { console.warn("moves nav", e); }
  if (typeof EXTRA_TITLES !== "undefined") EXTRA_TITLES.moves = () => ({ title: T("حركة العمالة", "Staff movement"), sub: T("مين كان فين وإمتى — من كمبيوتر التحليل، للمالك بس", "Who was where and when — from the analysis computer, owner only") });
  const s = document.createElement("style"); s.id = "nfmv-css";
  s.textContent = `.nfmv-cam{display:flex;flex-direction:column;gap:6px}.nfmv-cam h4{margin:0;font-size:14px}
.nfmv-p{display:flex;gap:8px;align-items:center;justify-content:space-between;border:0;background:rgba(0,0,0,.04);border-radius:8px;padding:7px 10px;font:inherit;font-size:13px;cursor:pointer;width:100%;text-align:start}
.nfmv-p small{color:var(--ink2,#666)}.nfmv-p .b{font-size:11px;background:rgba(240,170,0,.18);color:#8a5a00;border-radius:6px;padding:1px 6px}
.nfmv-tl{display:flex;flex-direction:column;gap:4px;font-size:13px}.nfmv-tl div{display:grid;grid-template-columns:120px 1fr auto;gap:8px;padding:5px 0;border-bottom:1px solid rgba(0,0,0,.06)}
.nfface .f2name{width:100%;justify-content:center}
#nfnamer{position:fixed;inset:0;z-index:100001;background:rgba(0,0,0,.5);display:flex;align-items:flex-end;justify-content:center}
#nfnamer .sh{background:var(--card,#fff);color:inherit;width:min(520px,100%);max-height:80vh;border-radius:16px 16px 0 0;padding:14px;display:flex;flex-direction:column;gap:8px}
#nfnamer .ls{overflow:auto;display:flex;flex-direction:column;gap:4px}#nfnamer .ls button{border:0;background:rgba(0,0,0,.05);border-radius:8px;padding:10px;font:inherit;text-align:start;cursor:pointer}`;
  document.head.appendChild(s);

  async function load() {
    if (!can() || st.busy) return; st.busy = true;
    const day = st.day || today(), a = new Date(day + "T00:00:00"), b = new Date(a.getTime() + 86400000);
    try {
      const { data, error } = await S.sb.from("stays").select("id,label,cam_id,cam_name,t0,t1,how,score,n").gte("t1", a.toISOString()).lt("t0", b.toISOString()).order("t0", { ascending: true }).limit(3000);
      if (error) throw error; st.rows = data || []; st.err = ""; st.at = Date.now();
    } catch (e) { st.err = String((e && e.message) || e || "").slice(0, 120); if (!st.rows) st.rows = []; }
    finally { st.busy = false; }
    paint();
  }
  function bodyHtml() {
    if (!st.rows) return `<div class="muted small">${H(T("بنجيب الحركة…", "Loading movement…"))}</div>`;
    if (st.err) return `<div class="banner warn"><span>${H(T("تعذّر التحميل: ", "Could not load: ") + st.err)}</span></div>`;
    if (!st.rows.length) return `<div class="banner info"><span>${H(T("مفيش حركة متسجّلة في اليوم ده. الحركة بتتسجّل لما كمبيوتر التحليل يشتغل على الكاميرات.", "No movement recorded on this day. Movement is recorded once the analysis computer is running on the cameras."))}</span></div>`;
    if (st.who) { // one person's day
      const r = st.rows.filter((x) => x.label === st.who);
      return `<div class="card"><div class="row" style="justify-content:space-between;align-items:center;gap:8px"><b class="notr" dir="auto">${H(nameOf(st.who))}</b><button type="button" class="btn sm" data-mv="back"><span>${H(T("رجوع", "Back"))}</span></button></div>
        <div class="nfmv-tl" style="margin-top:8px">${r.map((x) => `<div><span>${H(hm(x.t0))} – ${H(hm(x.t1))}</span><span class="notr" dir="auto">${H(x.cam_name || x.cam_id)}</span><small>${H(dur(x.t0, x.t1))}${x.how === "body" ? " · " + H(T("بشكل الجسم", "by body")) : ""}</small></div>`).join("")}</div></div>`;
    }
    const isToday = (st.day || today()) === today(), now = Date.now(), last = {};
    st.rows.forEach((x) => { if (!last[x.label] || x.t1 > last[x.label].t1) last[x.label] = x; });
    let ppl = Object.values(last); if (isToday) ppl = ppl.filter((x) => now - Date.parse(x.t1) < 10 * 60000);
    const cams = {}; ppl.forEach((x) => { (cams[x.cam_name || x.cam_id] = cams[x.cam_name || x.cam_id] || []).push(x); });
    const head = isToday ? T(`دلوقتي (آخر 10 دقايق): ${ppl.length} شخص`, `Now (last 10 minutes): ${ppl.length} people`) : T(`آخر مكان لكل شخص في اليوم ده: ${ppl.length}`, `Last place of each person that day: ${ppl.length}`);
    const all = [...new Set(st.rows.map((x) => x.label))];
    return `<div class="small muted" style="margin:2px 0 8px">${H(head)}</div>${Object.keys(cams).sort().map((c) => `<div class="card nfmv-cam"><h4 class="notr" dir="auto">${H(c)} · ${cams[c].length}</h4>${cams[c].sort((a, b) => (a.t1 < b.t1 ? 1 : -1)).map(pHtml).join("")}</div>`).join("") || `<div class="banner info"><span>${H(T("محدش قدام أي كاميرا دلوقتي.", "Nobody in front of any camera right now."))}</span></div>`}
      <div class="card nfmv-cam"><h4>${H(T(`كل اللي اتشافوا في اليوم (${all.length}) — دوس على حد تشوف يومه`, `Everyone seen that day (${all.length}) — tap someone to see their day`))}</h4>${all.sort((a, b) => nameOf(a).localeCompare(nameOf(b), "ar")).map((l) => pHtml(last[l])).join("")}</div>`;
  }
  const pHtml = (x) => `<button type="button" class="nfmv-p" data-mv="who" data-l="${H(x.label)}"><span class="notr" dir="auto">${H(nameOf(x.label))}${x.how === "body" ? ` <span class="b">${H(T("بشكل الجسم", "by body"))}</span>` : ""}</span><small>${H(x.cam_name || "")} · ${H(hm(x.t1))}</small></button>`;
  function paint() { const b = document.getElementById("nfmvbody"); if (b) b.innerHTML = bodyHtml(); const d = document.querySelector("[data-mvday]"); if (d && !d.value) d.value = st.day || today(); }
  EXTRA_VIEWS.moves = () => {
    if (!can()) return `<div class="card"><p class="small ink2">${H(T("الصفحة دي للمالك بس.", "This page is for the owner only."))}</p></div>`;
    setTimeout(() => { paint(); if (!st.rows || Date.now() - st.at > 20000) load(); }, 30);
    clearInterval(st.timer); st.timer = setInterval(() => { if (!/^#\/moves(\/|$)/.test(location.hash) || document.hidden) return; if ((st.day || today()) === today()) load(); }, 30000);
    return `<div class="stack"><div class="small ink2">${H(T("مين قدام أنهي كاميرا، وخط يوم كل شخص. «بشكل الجسم» = وشه مابانش واتعرف من شكله وهدومه (أقل دقة).", "Who is in front of which camera, and each person's day. “By body” = the face was not seen; recognised by look and clothes (less exact)."))}</div>
      <div class="nffbar"><input type="date" class="input" data-mvday max="${H(today())}" style="max-width:170px"><button type="button" class="btn sm" data-mv="refresh">${typeof icon === "function" ? icon("refresh") : ""}<span>${H(T("تحديث", "Refresh"))}</span></button></div><div id="nfmvbody"></div></div>`;
  };

  /* ---- «سمّيه» on «مين اتشاف فين» ---- */
  function addNameButtons() {
    if (!can() || !/^#\/faces(\/|$)/.test(location.hash)) return;
    document.querySelectorAll("#nff2list .nfface").forEach((tile) => {
      if (tile.querySelector(".f2name")) return; const r = tile.querySelector("[data-f2rec]"); if (!r) return;
      const b = document.createElement("button"); b.type = "button"; b.className = "btn sm f2name"; b.setAttribute("data-mvname", r.getAttribute("data-f2rec")); b.innerHTML = `<span>${H(T("سمّيه", "Name"))}</span>`; tile.appendChild(b);
    });
  }
  function closeNamer() { const o = document.getElementById("nfnamer"); if (o) o.remove(); }
  function openNamer(evId) {
    closeNamer(); const o = document.createElement("div"); o.id = "nfnamer"; o.setAttribute("data-ev", evId);
    o.innerHTML = `<div class="sh"><b>${H(T("ده مين؟", "Who is this?"))}</b><input class="input" data-mvq placeholder="${H(T("اكتب اسم العامل", "Type the worker's name"))}"><div class="ls"></div><div class="small" data-mvmsg style="min-height:18px"></div><button type="button" class="btn" data-mv="nclose"><span>${H(T("إلغاء", "Cancel"))}</span></button></div>`;
    document.body.appendChild(o); fillNamer("");
  }
  function fillNamer(q) {
    const ls = document.querySelector("#nfnamer .ls"); if (!ls) return; q = String(q || "").trim().toLowerCase();
    const w = workers().filter((x) => !q || String(x.name).toLowerCase().includes(q) || String(x.code || "").toLowerCase().includes(q)).sort((a, b) => String(a.name).localeCompare(String(b.name), "ar")).slice(0, 60);
    ls.innerHTML = w.map((x) => `<button type="button" class="notr" dir="auto" data-mv="pick" data-w="${H(x.id)}">${H(x.name)}</button>`).join("") || `<div class="muted small">${H(T("مفيش عامل بالاسم ده", "No worker with that name"))}</div>`;
  }
  async function pick(wid) {
    const o = document.getElementById("nfnamer"); if (!o) return; const m = o.querySelector("[data-mvmsg]"); m.textContent = T("بنسجّل…", "Saving…");
    let r = null, er = "";
    try { const x = await S.sb.rpc("vision_name", { p_event: Number(o.getAttribute("data-ev")), p_worker: wid }); r = x && x.data; er = x && x.error ? String(x.error.message || "error") : ""; } catch (e) { er = "net"; }
    if (r && r.ok) { closeNamer(); try { window.__nfFaces2 && window.__nfFaces2.load(); } catch (e) {} if (typeof toast === "function") { try { toast(T(`اتسمّى ✓ — ${r.captures} التقاط`, `Named ✓ — ${r.captures} captures`)); } catch (e) {} } }
    else m.textContent = T("ماتسجّلش: ", "Not saved: ") + (er || "server");
  }
  document.addEventListener("click", (ev) => {
    const t = ev.target && ev.target.closest ? ev.target : null; if (!t) return;
    const nb = t.closest("[data-mvname]"); if (nb) { ev.preventDefault(); ev.stopPropagation(); return openNamer(nb.getAttribute("data-mvname")); }
    const b = t.closest("[data-mv]"); if (!b) { if (t.id === "nfnamer") closeNamer(); return; }
    ev.preventDefault(); const k = b.getAttribute("data-mv");
    if (k === "who") { st.who = b.getAttribute("data-l") || ""; return paint(); }
    if (k === "back") { st.who = ""; return paint(); }
    if (k === "refresh") return void load();
    if (k === "nclose") return closeNamer();
    if (k === "pick") return void pick(b.getAttribute("data-w"));
  }, true);
  document.addEventListener("input", (ev) => { const t = ev.target; if (t && t.matches && t.matches("[data-mvq]")) fillNamer(t.value); });
  document.addEventListener("change", (ev) => { const t = ev.target; if (t && t.matches && t.matches("[data-mvday]")) { st.day = t.value || today(); st.rows = null; st.who = ""; paint(); load(); } });
  window.addEventListener("hashchange", closeNamer);
  setInterval(addNameButtons, 800);
  window.__nfMoves = { st, load, paint, addNameButtons, openNamer };
})();
;(function(){if(window.__NF_A1160__||(window.__NF_A1160__=1,typeof isStuSys=="function"&&isStuSys()||typeof isConstruction=="function"&&isConstruction()))return;const T=()=>typeof I18N!="undefined"&&I18N.lang==="en",h=(e,t)=>T()?t:e,d={rwDirect:0,rwMgr:0,bellHid:0,pushCut:0},_=["manager","vice","admin"];function p(e){try{const t=String(e&&e.createdBy||"");if(t==="owner"||t.indexOf("sb:")===0)return"top";const n=t.indexOf("w:")===0?byId("workers",t.slice(2)):t.indexOf("s:")===0?byId("staff",t.slice(2)):null;if(n)return _.indexOf(n.role)>=0?"top":"lead"}catch{}return null}const f=new Map,x=e=>!!e&&e.type==="restwork"&&e.status==="pending"&&!!e.taskId&&Array.isArray(e.chain)&&e.chain.length===1&&e.chain[0]==="admin"&&!(+e.step>0)&&!(Array.isArray(e.approvals)&&e.approvals.length);if(typeof Store=="object"&&Store&&typeof Store.save=="function"&&(Store.save=(e=>function(t,n){try{if(t==="requests"&&x(n)&&!byId("requests",n.id)){const r=p(byId("tasks",n.taskId));if(r==="top")return f.set(n.id,{mode:"direct",at:Date.now()}),d.rwDirect++,Promise.resolve(n);if(r==="lead"){n.chain=["manager"];const s=i=>String(i||"").replace("\u0628\u0639\u062F \u0645\u0648\u0627\u0641\u0642\u0629 \u0627\u0644\u0625\u062F\u0627\u0631\u0629","\u0628\u0639\u062F \u0645\u0648\u0627\u0641\u0642\u0629 \u0645\u062F\u064A\u0631 \u0627\u0644\u0645\u0635\u0646\u0639");Array.isArray(n.thread)&&(n.thread=n.thread.map(i=>i&&i.kind==="system"?Object.assign({},i,{text:s(i.text)}):i)),f.set(n.id,{mode:"mgr",at:Date.now()}),d.rwMgr++}f.size>200&&f.delete(f.keys().next().value)}}catch{}return e.apply(this,arguments)})(Store.save)),typeof toast=="function")try{toast=(e=>function(t,n){try{if(typeof t=="string"&&(t.indexOf("\u0648\u0627\u0644\u064A\u0648\u0645 \u0647\u064A\u062A\u062D\u0633\u0628 \u0628\u0639\u062F \u0645\u0648\u0627\u0641\u0642\u0629 \u0627\u0644\u0625\u062F\u0627\u0631\u0629")>=0||t.indexOf("the day counts once the management approves")>=0)){let r="";f.forEach(s=>{Date.now()-s.at<6e3&&(r=s.mode)}),r==="direct"?t=h("\u064A\u0648\u0645 \u0631\u0627\u062D\u0629 \u2014 \u0628\u0635\u0645\u062A\u0643 \u0627\u062A\u0633\u062C\u0651\u0644\u062A \u0648\u0627\u0644\u064A\u0648\u0645 \u0645\u062D\u0633\u0648\u0628 (\u0627\u0644\u0645\u0647\u0645\u0629 \u0645\u0646 \u0627\u0644\u0625\u062F\u0627\u0631\u0629)","Rest day \u2014 your punch is saved and the day counts (the task is from the management)"):r==="mgr"&&(t=h("\u064A\u0648\u0645 \u0631\u0627\u062D\u0629 \u2014 \u0628\u0635\u0645\u062A\u0643 \u0627\u062A\u0633\u062C\u0651\u0644\u062A\u060C \u0648\u0627\u0644\u064A\u0648\u0645 \u0647\u064A\u062A\u062D\u0633\u0628 \u0628\u0639\u062F \u0645\u0648\u0627\u0641\u0642\u0629 \u0645\u062F\u064A\u0631 \u0627\u0644\u0645\u0635\u0646\u0639","Rest day \u2014 your punch is saved; the day counts once the factory manager approves"))}}catch{}return e.call(this,t,n)})(toast)}catch{}const w=()=>{try{return typeof escOwnerIds=="function"?escOwnerIds():new Set}catch{return new Set}},c=(e,t)=>{if(e==null||e==="")return!1;const n=String(e);return n==="owner"||n.indexOf("sb:")===0||t.has(n)||t.has(n.replace(/^[ws]:/,""))},D=24*36e5,N=e=>!!(e.escalation&&+e.escalation.level>=3||e.accRoleEsc),g=(e,t)=>c(e.assigneeId,t)||Array.isArray(e.assigneeIds)&&e.assigneeIds.some(n=>c(n,t))||e.toRole==="admin"||N(e),R=(e,t,n)=>{try{if(!e.replyTo)return!1;if(c(e.replyTo.by,t))return!0;const r=(n||[]).find(s=>s&&s.id===e.replyTo.id);return!!r&&c(r.by,t)}catch{return!1}},m=(e,t,n,r)=>Array.isArray(e.mentions)&&e.mentions.some(s=>c(s,t))||R(e,t,r)||!!e.sys&&/للمالك/.test(String(e.text||""))||!!n&&e.at>n&&new Date(e.at).getTime()-new Date(n).getTime()<=D;function O(e){const t=w();if(myIds().forEach(a=>t.add(String(a))),g(e,t))return!0;const n=S.session||{},r=(e.threadSeen||{})[n.id]||(e.threadSeen||{})[n.workerId]||"";let s="";const i=taskThread(e);for(const a of i)if(!(!a||!a.at)){if(c(a.by,t)){a.at>s&&(s=a.at);continue}if(a.at>r&&m(a,t,s,i))return!0}return!1}const E=()=>{try{return!!S.session&&typeof isAdmin=="function"&&isAdmin()&&!(S.viewOrig||S.demoOrig)}catch{return!1}};typeof notifItems=="function"&&(notifItems=(e=>function(){const t=e.apply(this,arguments);try{return!E()||!Array.isArray(t)?t:t.filter(n=>{if(!n||n.kind!=="chat")return!0;const r=/^#\/tasks\/([^/?#]+)/.exec(String(n.href||"")),s=r&&byId("tasks",r[1]);return s?O(s):!0})}catch{return t}})(notifItems));function I(e,t,n){try{const r=String(n||"");let s=/^rw-(.+)$/.exec(r);if(s){const i=f.get(s[1]);return i&&i.mode==="direct"?null:i&&i.mode==="mgr"?["role:manager"]:e}if(s=/^task-(.+)$/.exec(r),s&&Array.isArray(e)&&e.length){const i=byId("tasks",s[1]),a=S.session&&S.session.name||"\u0631\u0633\u0627\u0644\u0629";if(!i||String(t||"").indexOf(a+" \u2014 ")!==0)return e;const u=w();if(!e.some(o=>c(o,u))||g(i,u))return e;const y=taskThread(i),b=y[y.length-1];let l="";if(y.forEach(o=>{o&&o.at&&c(o.by,u)&&o.at>l&&(l=o.at)}),b&&m(Object.assign({},b,{sys:!1}),u,l,y))return e;try{const o=S.ui&&S.ui.chatReply;if(o){const k=y.find(v=>v&&v.id===o.id);if(c(o.by,u)||k&&c(k.by,u))return e}}catch{}d.pushCut++;const A=e.filter(o=>!c(o,u));return A.length?A:null}}catch{}return e}typeof pushSend=="function"&&(pushSend=(e=>function(t,n,r,s,i){const a=I(t,n,i);return a===null?Promise.resolve({ok:!0,skipped:!0}):e.call(this,a,n,r,s,i)})(pushSend)),window.nfOwnerQuiet={stats:()=>Object.assign({},d),rwLevel:p,chatForOwner:O,route:I,recent:f}})();
;(function(){if(window.__NF_A1161__||(window.__NF_A1161__=1,typeof isStuSys=="function"&&isStuSys()||typeof isConstruction=="function"&&isConstruction())||typeof vTaskDetail!="function")return;const E=()=>typeof I18N!="undefined"&&I18N.lang==="en",i=(e,n)=>E()?n:e,a=e=>typeof esc=="function"?esc(String(e==null?"":e)):String(e==null?"":e).replace(/[&<>"]/g,n=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[n]),w=e=>{try{return e?typeof fmtTm=="function"?fmtTm(e):e:"\u2014"}catch{return e||"\u2014"}},h=e=>{try{return typeof fmtDate=="function"?fmtDate(e):e}catch{return e}},y=new Map,g=e=>{let n=y.get(e);return n||(n={rows:{},none:!1,extra:"",err:""},y.set(e,n)),n},N=e=>e&&e.crewAsk&&Array.isArray(e.crewAsk.pool)?e.crewAsk.pool.filter(n=>n&&n.id&&n.name):[],I=e=>{try{return!!e&&!!e.crewAsk&&!e.crewAsk.answer&&["open","doing"].indexOf(e.status)>=0&&(typeof writable!="function"||writable())&&(myIds().indexOf(e.assigneeId)>=0||isAdmin())}catch{return!1}},b=e=>{const n=e.crewAsk;return i(`\u0645\u064A\u0646 \u0631\u0627\u062D ${n.place||""}${n.date?" \u064A\u0648\u0645 "+h(n.date):""}\u061F`,`Who went to ${n.place||""}${n.date?" on "+h(n.date):""}?`)};function j(e){const n=e.crewAsk;if(!n)return"";if(n.answer){const t=n.answer,s=Array.isArray(t.rows)?t.rows:[];return`<div class="card nfca done"><div class="nfca-h"><h3>${a(b(e))}</h3><div class="grow"></div><span class="badge ok">${a(i("\u0627\u062A\u0631\u062F \u0639\u0644\u064A\u0647","Answered"))}</span></div>
        ${s.length?`<div class="nfca-a">${s.map(o=>`<div class="nfca-ar"><b>${a(o.name)}</b><span>${a(i("\u0648\u0635\u0644","Came"))} ${a(w(o.in))}</span><span>${a(i("\u0645\u0634\u064A","Left"))} ${a(w(o.out))}</span></div>`).join("")}</div>`:`<div class="small">${a(i("\u0645\u062D\u062F\u0634 \u0631\u0627\u062D.","Nobody went."))}</div>`}
        ${t.extra?`<div class="small" style="margin-top:8px;white-space:pre-wrap">${a(i("\u0643\u0645\u0627\u0646: ","Also: ")+t.extra)}</div>`:""}
        <div class="tiny muted" style="margin-top:8px">${a((t.byName||"")+(t.at?" \xB7 "+h(String(t.at).slice(0,10)):""))}</div></div>`}if(!I(e))return`<div class="card nfca"><div class="nfca-h"><h3>${a(b(e))}</h3></div><div class="small muted">${a(i("\u0645\u0633\u062A\u0646\u064A \u0631\u062F \u0627\u0644\u0645\u0643\u0644\u064E\u0651\u0641 \u0628\u0627\u0644\u0645\u0647\u0645\u0629.","Waiting for the assignee to answer."))}</div></div>`;const r=g(e.id);return`<div class="card nfca" data-ca="${a(e.id)}"><div class="nfca-h"><h3>${a(b(e))}</h3></div>
      <div class="small muted">${a(i("\u0639\u0644\u0651\u0645 \u0639\u0644\u0649 \u0643\u0644 \u0648\u0627\u062D\u062F \u0631\u0627\u062D\u060C \u0648\u0627\u0643\u062A\u0628 \u0648\u0635\u0644 \u0627\u0644\u0633\u0627\u0639\u0629 \u0643\u0627\u0645 \u0648\u0645\u0634\u064A \u0627\u0644\u0633\u0627\u0639\u0629 \u0643\u0627\u0645.","Tick everyone who went, and write when each one came and left."))}</div>
      <div class="nfca-l">${N(e).map(t=>{const s=r.rows[t.id]||{};return`<div class="nfca-r${s.on?" on":""}" data-ca-row="${a(t.id)}">
        <label class="nfca-n"><input type="checkbox" data-ca-on="${a(t.id)}"${s.on?" checked":""}><span>${a(t.name)}</span></label>
        <div class="nfca-t"><label>${a(i("\u0648\u0635\u0644","Came"))}<input type="time" data-ca-in="${a(t.id)}" value="${a(s.in||"")}"></label><label>${a(i("\u0645\u0634\u064A","Left"))}<input type="time" data-ca-out="${a(t.id)}" value="${a(s.out||"")}"></label></div></div>`}).join("")}</div>
      <label class="nfca-none"><input type="checkbox" data-ca-none${r.none?" checked":""}><span>${a(i("\u0645\u062D\u062F\u0634 \u0631\u0627\u062D","Nobody went"))}</span></label>
      <input class="inp nfca-x" type="text" data-ca-extra value="${a(r.extra||"")}" placeholder="${a(i("\u062D\u062F \u062A\u0627\u0646\u064A \u0645\u0634 \u0641\u064A \u0627\u0644\u0642\u0627\u064A\u0645\u0629\u061F \u0627\u0643\u062A\u0628 \u0627\u0633\u0645\u0647 \u0648\u0645\u0648\u0627\u0639\u064A\u062F\u0647 (\u0627\u062E\u062A\u064A\u0627\u0631\u064A)","Someone not on the list? Name and times (optional)"))}">
      <div class="nfca-e small" data-ca-err>${a(r.err||"")}</div>
      <button type="button" class="btn p" data-ca-send="${a(e.id)}">${a(i("\u0627\u0628\u0639\u062A \u0627\u0644\u0631\u062F","Send the answer"))}</button></div>`}vTaskDetail=(e=>function(n){const r=e.apply(this,arguments);try{return!n||!n.crewAsk||typeof r!="string"||r.indexOf('class="grid g2"')<0?r:j(n)+r}catch{return r}})(vTaskDetail);const T=e=>e&&e.closest?e.closest("[data-ca]"):null,_=e=>{const n=e.target,r=T(n);if(!r)return;const t=g(r.dataset.ca);if(t.err){t.err="";const s=r.querySelector("[data-ca-err]");s&&(s.textContent="")}if(n.dataset.caOn!=null){const s=n.dataset.caOn;t.rows[s]=Object.assign({},t.rows[s],{on:n.checked});const o=n.closest(".nfca-r");if(o&&o.classList.toggle("on",n.checked),n.checked&&t.none){t.none=!1;const d=r.querySelector("[data-ca-none]");d&&(d.checked=!1)}}else if(n.dataset.caIn!=null){const s=n.dataset.caIn;t.rows[s]=Object.assign({},t.rows[s],{in:n.value})}else if(n.dataset.caOut!=null){const s=n.dataset.caOut;t.rows[s]=Object.assign({},t.rows[s],{out:n.value})}else n.hasAttribute("data-ca-none")?(t.none=n.checked,n.checked&&(Object.keys(t.rows).forEach(s=>{t.rows[s].on=!1}),r.querySelectorAll("[data-ca-on]").forEach(s=>{s.checked=!1}),r.querySelectorAll(".nfca-r").forEach(s=>s.classList.remove("on")))):n.hasAttribute("data-ca-extra")&&(t.extra=n.value)};document.addEventListener("change",_,!0),document.addEventListener("input",_,!0);const x=(e,n,r)=>{n.err=r;const t=e&&e.querySelector("[data-ca-err]");t&&(t.textContent=r)};let v=!1;document.addEventListener("click",async e=>{const n=e.target&&e.target.closest?e.target.closest("[data-ca-send]"):null;if(!n||(e.preventDefault(),v))return;const r=n.dataset.caSend,t=byId("tasks",r),s=T(n);if(!t||!I(t))return;const o=g(r),d=String(o.extra||"").trim(),l=N(t).filter(c=>o.rows[c.id]&&o.rows[c.id].on).map(c=>({id:c.id,name:c.name,in:o.rows[c.id].in||"",out:o.rows[c.id].out||""}));if(!l.length&&!d&&!o.none)return x(s,o,i("\u0639\u0644\u0651\u0645 \u0639\u0644\u0649 \u0627\u0644\u0644\u064A \u0631\u0627\u062D\u0648\u0627\u060C \u0623\u0648 \u0627\u062E\u062A\u0627\u0631 \xAB\u0645\u062D\u062F\u0634 \u0631\u0627\u062D\xBB.","Tick who went, or choose \xABNobody went\xBB."));const $=l.find(c=>!c.in||!c.out);if($)return x(s,o,i(`\u0627\u0643\u062A\u0628 \u0648\u0635\u0644 \u0648\u0645\u0634\u064A \u0627\u0644\u0633\u0627\u0639\u0629 \u0643\u0627\u0645 \u0644\u0640 ${$.name}.`,`Write when ${$.name} came and left.`));const k=l.find(c=>c.out<=c.in);if(k)return x(s,o,i(`\u0648\u0642\u062A \u0627\u0644\u0645\u0634\u064A \u0644\u0627\u0632\u0645 \u064A\u0643\u0648\u0646 \u0628\u0639\u062F \u0627\u0644\u0648\u0635\u0648\u0644 \u2014 ${k.name}.`,`The leaving time must be after the arrival \u2014 ${k.name}.`));v=!0,n.disabled=!0;try{const c=S.session||{},f=nowISO(),u=c.id||c.workerId||null,m=t.crewAsk,L={rows:l,none:!l.length&&!d,extra:d,at:f,by:u,byName:c.name||""},A=l.map(p=>`\u2022 ${p.name} \u2014 \u0648\u0635\u0644 ${w(p.in)} \xB7 \u0645\u0634\u064A ${w(p.out)}`),C=`\u0627\u0644\u0631\u062F \u0639\u0644\u0649 \xAB\u0645\u064A\u0646 \u0631\u0627\u062D ${m.place||""}${m.date?" \u064A\u0648\u0645 "+h(m.date):""}\xBB:
`+(A.length?A.join(`
`):d?"":"\u0645\u062D\u062F\u0634 \u0631\u0627\u062D.")+(d?`${A.length?`
`:""}\u0643\u0645\u0627\u0646: ${d}`:""),B={id:uid(),at:f,by:u,byName:c.name||"",text:C};t.createdBy&&myIds().indexOf(t.createdBy)<0&&(B.mentions=[t.createdBy]);const O=Object.assign({},t.threadSeen||{});u&&(O[u]=f),c.workerId&&(O[c.workerId]=f),await Store.update("tasks",r,{crewAsk:Object.assign({},m,{answer:L}),thread:taskThread(t).concat([B]),threadSeen:O,lastMsgAt:f,status:"done",doneAt:f,doneBy:u,doneByName:c.name||"",updatedAt:f}),y.delete(r);try{const p=t.createdBy==="owner"||String(t.createdBy||"").indexOf("sb:")===0||!t.createdBy?["role:admin"]:[t.createdBy];typeof pushSend=="function"&&pushSend(p,`${c.name||""} \u0631\u062F: \u0645\u064A\u0646 \u0631\u0627\u062D ${m.place||""}`.slice(0,100),(l.length?l.map(D=>D.name).join("\u060C "):"\u0645\u062D\u062F\u0634 \u0631\u0627\u062D").slice(0,140),`/#/tasks/${r}`,"task-"+r)}catch{}try{toast(i("\u0627\u0644\u0631\u062F \u0627\u062A\u0628\u0639\u062A \u2713","Answer sent \u2713"))}catch{}try{typeof rerender=="function"?rerender():render(!1)}catch{}}catch(c){n.disabled=!1,x(s,o,i("\u0645\u0627\u062A\u0628\u0639\u062A\u0634 \u2014 \u062C\u0631\u0651\u0628 \u062A\u0627\u0646\u064A.","Not sent \u2014 try again."));try{console.warn("crew ask",c)}catch{}}v=!1},!0);try{(document.head||document.documentElement).insertAdjacentHTML("beforeend",`<style id="nf-crewask">
.nfca-h{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:6px}.nfca-h h3{margin:0;font-size:17px}
.nfca-l{display:flex;flex-direction:column;margin:10px 0 6px}
.nfca-r{display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:9px 2px;border-top:1px solid var(--line)}.nfca-r:first-child{border-top:0}
.nfca-n,.nfca-none{display:flex;align-items:center;gap:10px;flex:1 1 150px;min-width:0;cursor:pointer;font-weight:600}
.nfca-n input,.nfca-none input{width:22px;height:22px;flex:none}
.nfca-t{display:none;gap:8px;flex:1 1 220px}.nfca-r.on .nfca-t{display:flex}
.nfca-t label{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--muted);flex:1}
.nfca-t input{flex:1;min-width:0;font-size:16px;padding:7px 8px;border:1px solid var(--line);border-radius:10px;background:var(--surface);color:inherit}
.nfca-none{padding:10px 2px;border-top:1px solid var(--line);font-weight:500}
.nfca-x{width:100%;margin:8px 0;font-size:16px}
.nfca-e{color:var(--crit,#b91c1c);min-height:18px;margin-bottom:6px}
.nfca-a{display:flex;flex-direction:column}.nfca-ar{display:flex;gap:12px;flex-wrap:wrap;align-items:baseline;padding:8px 2px;border-top:1px solid var(--line)}.nfca-ar:first-child{border-top:0}.nfca-ar b{flex:1 1 140px}.nfca-ar span{color:var(--muted);font-size:13px}
</style>`)}catch{}window.nfCrewAsk={card:j,draft:y}})();
;(function(){if(window.__NF_A1163__||(window.__NF_A1163__=1,typeof isStuSys=="function"&&isStuSys()||typeof isConstruction=="function"&&isConstruction())||typeof missedCheckouts!="function"||typeof outFixDialog!="function")return;const b=()=>typeof I18N!="undefined"&&I18N.lang==="en",c=(t,e)=>b()?e:t,i=t=>typeof esc=="function"?esc(String(t==null?"":t)):String(t==null?"":t),u={reopened:0,cards:0,hints:0},f=()=>{try{return S.session&&S.session.workerId?byId("workers",S.session.workerId):null}catch{return null}},l=t=>{try{const e=t?missedCheckouts(t):[];return e&&e.length?e[0]:""}catch{return""}},p=t=>{try{return!!((attendanceFor(todayISO())||{})[t.id]||{}).in}catch{return!1}},a=t=>{try{return fmtDate(t)}catch{return t}},y=(t,e)=>p(t)?c(`\u0646\u0633\u064A\u062A \u062A\u0633\u062C\u0651\u0644 \u0627\u0646\u0635\u0631\u0627\u0641 \u064A\u0648\u0645 ${a(e)}. \u0627\u0643\u062A\u0628 \u0648\u0642\u062A \u0627\u0646\u0635\u0631\u0627\u0641\u0643 \u0639\u0634\u0627\u0646 \u0627\u0644\u064A\u0648\u0645 \u064A\u062A\u062D\u0633\u0628.`,`You did not punch out on ${a(e)}. Write when you left so the day counts.`):c(`\u0646\u0633\u064A\u062A \u062A\u0633\u062C\u0651\u0644 \u0627\u0646\u0635\u0631\u0627\u0641 \u064A\u0648\u0645 ${a(e)} \u2014 \u0639\u0634\u0627\u0646 \u0643\u062F\u0647 \u0628\u0635\u0645\u0629 \u062D\u0636\u0648\u0631 \u0627\u0644\u0646\u0647\u0627\u0631\u062F\u0647 \u0645\u0627\u0628\u062A\u062A\u0633\u062C\u0651\u0644\u0634. \u0627\u0643\u062A\u0628 \u0648\u0642\u062A \u0627\u0646\u0635\u0631\u0627\u0641\u0643 \u0627\u0644\u0623\u0648\u0644.`,`You did not punch out on ${a(e)} \u2014 that is why today's punch-in is not saved. Write when you left first.`);let s=null;const g=()=>{try{return!!(typeof _modal!="undefined"&&_modal&&/انصراف منسي/.test(String(_modal.title||""))&&document.querySelector("#modalroot #mform"))}catch{return!1}},w=outFixDialog;outFixDialog=function(t,e,n){const r=w.apply(this,arguments);try{const o={w:t,d:e,cb:n,user:!1,n:0,t0:Date.now()};s=o;const d=setInterval(()=>{try{if(s!==o||o.user||Date.now()-o.t0>2e4||l(t)!==e){clearInterval(d),s===o&&(s=null);return}if(g())return;const h=document.getElementById("modalroot");if(h&&h.children.length)return;if(o.n>=3){clearInterval(d),s=null;return}o.n++,u.reopened++,w.call(this,t,e,n)}catch{clearInterval(d)}},350)}catch{}return r};const m=()=>{s&&(s.user=!0)};document.addEventListener("click",t=>{try{const e=t.target;if(!e||!e.closest||!e.closest("#modalroot"))return;(e.closest('[data-action="closemodal"]')||e.id==="overlay")&&m()}catch{}},!0),document.addEventListener("submit",t=>{try{t.target&&t.target.id==="mform"&&m()}catch{}},!0),document.addEventListener("keydown",t=>{t.key==="Escape"&&m()},!0);const v=()=>{const t=f(),e=l(t);return!t||!e?"":(u.cards++,`<div class="card nfmo" id="nfmo"><div class="nfmo-t">\u26A0\uFE0F ${i(c("\u0627\u0646\u0635\u0631\u0627\u0641 \u0645\u0646\u0633\u064A","Missed punch-out"))} \u2014 ${i(a(e))}</div><div class="small nfmo-b">${i(y(t,e))}</div><button type="button" class="btn p" data-nfmo="${i(e)}">${i(c("\u0627\u0643\u062A\u0628 \u0648\u0642\u062A \u0627\u0644\u0627\u0646\u0635\u0631\u0627\u0641","Write the leaving time"))}</button></div>`)};if(typeof vMe=="function"){const t=vMe,e=function(){let n=t.apply(this,arguments);try{if(typeof n=="string"){const r=v();r&&(n=r+n)}}catch{}return n};try{vMe=e}catch{}try{window.vMe=e}catch{}}document.addEventListener("click",t=>{if(!(t.target&&t.target.closest?t.target.closest("[data-nfmo]"):null))return;t.preventDefault();const n=f(),r=l(n);if(!n||!r){try{rerender()}catch{}return}outFixDialog(n,r,()=>{try{toast(c("\u0627\u062A\u0633\u062C\u0651\u0644 \u2713 \u2014 \u062F\u0644\u0648\u0642\u062A\u064A \u062A\u0642\u062F\u0631 \u062A\u0628\u0635\u0645","Saved \u2713 \u2014 you can punch now"))}catch{}try{rerender()}catch{}})},!0),typeof ACTIONS=="object"&&typeof ACTIONS.selfPunch=="function"&&(ACTIONS.selfPunch=(t=>async function(){let e;try{e=await t.apply(this,arguments)}finally{try{const n=f(),r=l(n);if(n&&r&&!p(n)){const o=document.getElementById("geo-live");if(o&&/جارٍ تحديد موقعك|Locating/.test(o.textContent||"")&&(o.textContent=y(n,r),u.hints++),!g()&&!(s&&s.user))try{toast(y(n,r),"err")}catch{}}}catch{}}return e})(ACTIONS.selfPunch));try{(document.head||document.documentElement).insertAdjacentHTML("beforeend",'<style id="nf-missedout">.nfmo{border-inline-start:4px solid var(--warn,#e5932a)}.nfmo-t{font-weight:800;font-size:16px;margin-bottom:4px}.nfmo-b{line-height:1.7;margin-bottom:10px}</style>')}catch{}window.nfMissedOut={stats:()=>Object.assign({},u),card:v}})();
