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
