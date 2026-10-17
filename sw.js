/* Ninety Fabrication — service worker (app shell cache). Data never lives here: it is on the server. */
const BUILD = '20261017-0417-88f4ea';
/* v4.17: several Ninety apps share one origin (/ = factory, /studioz/ = office) — each service worker keeps to its own scope and its own cache prefix */
const SCOPE = new URL(self.registration.scope).pathname;
const TAG = SCOPE.replace(/^\/|\/$/g, '').replace(/\//g, '-');
const CACHE = 'nf-shell-' + (TAG ? TAG + '-' : '') + BUILD;
const SHELL = ["./app.js?v=20261017-0417-88f4ea", "./index.html", "./config.js", "./manifest.json", "./vendor/supabase.js", "./vendor/three.bundle.js", "./vendor/pdf.min.js", "./vendor/pdf.worker.min.js", "./vendor/leaflet.js", "./icons/icon-192.png", "./icons/icon-512.png", "./en.json", "./laeha.pdf", "./lof-c01.pdf"];
self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL.map(u => new Request(u, { cache: 'reload' }))).catch(() => { })));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith('nf-shell-' + (TAG ? TAG + '-' : '')) && !(TAG ? false : /^nf-shell-[^\d]/.test(k)) && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
/* v5.44 — incoming call while the app is closed: ringing notification on the lock screen (buzzes again every few seconds while it rings)
   call:'<id>' = ringing · call:'stop:<id>' = answered / declined (remove it) · call:'end:<id>' = missed (replace with «مكالمة فايتة») */
const IOS = /iPhone|iPad|iPod/.test((self.navigator && self.navigator.userAgent) || '');
async function callPush(d, title, body, url) {
  const raw = String(d.call); const m = /^(stop|end):(.+)$/.exec(raw); const id = m ? m[2] : raw; const pre = 'call-' + id;
  const old = await self.registration.getNotifications().catch(() => []); old.forEach(n => { if (String(n.tag || '').startsWith(pre)) n.close(); });
  if (m && m[1] === 'stop') { try { await self.registration.showNotification('Ninety', { body: 'المكالمة خلصت', tag: 'callstop-' + id, silent: true }); (await self.registration.getNotifications({ tag: 'callstop-' + id })).forEach(n => n.close()); } catch (x) { /* ignore */ } return; }   // a push must show something (iOS / Chrome) → show + close at once
  if (m && m[1] === 'end') return self.registration.showNotification(title, { body, tag: 'missed-' + id, icon: './icons/icon-192.png', badge: './icons/icon-192.png', data: { url: './#/calls' } }).catch(() => { });
  const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true }).catch(() => []);
  if (wins.some(c => c.visibilityState === 'visible' && c.focused)) { try { await self.registration.showNotification(title, { body, tag: pre, silent: true, data: { url, call: id } }); } catch (x) { /* ignore */ } return; }   // app open in front → it rings on its own screen (quiet notification only)
  const data = { url, call: id };
  if (IOS) return self.registration.showNotification(title, { body, tag: pre + '-' + Date.now(), icon: './icons/icon-192.png', data }).catch(() => self.registration.showNotification(title, { body }));
  return self.registration.showNotification(title, { body, tag: pre, renotify: true, requireInteraction: true, silent: false, vibrate: [900, 400, 900, 400, 900, 400, 900], icon: './icons/icon-192.png', badge: './icons/icon-192.png', data,
    actions: [{ action: 'accept', title: 'رد' }, { action: 'decline', title: 'رفض' }] }).catch(() => self.registration.showNotification(title, { body, tag: pre, data }));
}
self.addEventListener('message', e => { if (e.data === 'skipWaiting') self.skipWaiting(); });
/* v6.34 — brand media cache: one copy per file on the device, independent of the app build.
   The full file is stored once; <video> range requests (Range: bytes=a-b) are answered as 206 slices of that copy, so the film never streams twice.
   A link's ?v= is its version: caching ?v=N drops every older ?v= of the same path. */
const MEDIA = 'nf-media';
async function mediaFetch(req, url) {
  const key = url.origin + url.pathname + url.search;
  const c = await caches.open(MEDIA);
  let full = await c.match(key);
  if (!full) {
    let r; try { r = await fetch(new Request(key, { mode: 'cors', credentials: 'omit' })); } catch (x) { return fetch(req); }
    if (!r.ok || r.status === 206) return r;   // not a full copy → pass through, cache nothing
    full = r.clone();
    const ks = await c.keys().catch(() => []);
    for (const k of ks) { try { const u = new URL(k.url); if (u.origin === url.origin && u.pathname === url.pathname && (u.origin + u.pathname + u.search) !== key) await c.delete(k); } catch (x) { /* ignore */ } }
    c.put(key, r).catch(() => { });
  }
  const range = req.headers.get('range');
  if (!range) return full;
  const buf = await full.arrayBuffer(); const total = buf.byteLength;
  const m = /bytes=(\d*)-(\d*)/.exec(range); let a = m && m[1] ? parseInt(m[1], 10) : 0; let b = m && m[2] ? parseInt(m[2], 10) : total - 1;
  if (isNaN(a) || a >= total) return new Response(null, { status: 416, headers: { 'Content-Range': 'bytes */' + total } });
  if (isNaN(b) || b >= total) b = total - 1;
  const h = new Headers(); const ct = full.headers.get('content-type'); if (ct) h.set('Content-Type', ct);
  h.set('Content-Range', 'bytes ' + a + '-' + b + '/' + total); h.set('Content-Length', String(b - a + 1)); h.set('Accept-Ranges', 'bytes');
  return new Response(buf.slice(a, b + 1), { status: 206, statusText: 'Partial Content', headers: h });
}
self.addEventListener('fetch', e => {
  /* v7.57: Android «Share» → Ninety (manifest share_target): keep the files for the app, then open it on #/share */
  if (e.request.method === 'POST' && new URL(e.request.url).pathname === SCOPE + 'share-target') {
    e.respondWith((async () => {
      try {
        const fd = await e.request.formData(); const c = await caches.open('nf-share');
        for (const k of await c.keys()) await c.delete(k);
        const files = fd.getAll('files').filter(f => f && typeof f !== 'string' && f.size).slice(0, 10);
        let i = 0; for (const f of files) await c.put(new Request(SCOPE + '__share/' + (i++)), new Response(f, { headers: { 'content-type': f.type || 'application/octet-stream', 'x-name': encodeURIComponent(f.name || 'file') } }));
        const text = [fd.get('title'), fd.get('text'), fd.get('url')].filter(x => typeof x === 'string' && x).join('\n');
        if (text) await c.put(new Request(SCOPE + '__share/text'), new Response(text));
      } catch (x) { /* open the app anyway */ }
      return Response.redirect(SCOPE + 'index.html#/share/sw', 303);
    })());
    return;
  }
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const same = url.origin === self.location.origin;
  if (same && !url.pathname.startsWith(SCOPE)) return; // another Ninety app on this origin — not ours
  if (same && SCOPE === '/' && /^\/(studioz|construction)\//.test(url.pathname)) return; // the root app never handles a sibling app's files
  if (same && /^\/c\//.test(url.pathname)) return; // v5.97: public client catalogue pages (/c/<slug>/) are not part of the app
  if (same && url.pathname === '/meet.html') return; // v7.48: the meeting guest page is its own page (never cached as the app)
  if (same && /^\/oauth\//.test(url.pathname)) return; // v7.66: the sign-in / consent page for ChatGPT is its own page (never cached as the app)
  if (same && (req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('/index.html'))) {
    // app page: network first (so updates arrive), cached copy when offline
    // (cache: 'no-cache' revalidates with the host even when it sends a max-age, e.g. GitHub Pages)
    e.respondWith(fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' }).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy)).catch(() => { }); return r; }).catch(() => caches.match('./index.html')));
    return;
  }
  if (same && url.pathname.endsWith('/config.js')) {
    // backend settings: network first so a changed key reaches devices without a new build
    e.respondWith(fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' }).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)).catch(() => { }); return r; }).catch(() => caches.match(req)));
    return;
  }
  if (/\/storage\/v1\/object\/public\/app\/brand\//.test(url.pathname) && /\.supabase\.co$/.test(url.host)) {
    // v6.34: brand media (login film, posters, renders, logo) — kept on the device across builds; a new version of a file arrives as a new ?v= on its link
    e.respondWith(mediaFetch(req, url));
    return;
  }
  if (same || /cdn\.jsdelivr\.net|cdnjs\.cloudflare\.com/.test(url.host)) {
    // shell files, vendor libraries, face models: cache first
    e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok || r.type === 'opaque') { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)).catch(() => { }); } return r; })));
  }
});
/* ---------- Web Push (chat messages, approvals, alerts) ---------- */
self.addEventListener('push', e => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch (x) { d = { body: e.data ? e.data.text() : '' }; }
  const title = String(d.title || 'Ninety Fabrication'); const body = String(d.body || ''); const tag = String(d.tag || 'nf-' + Date.now()); const url = d.url || './';
  if (d.call) { e.waitUntil(callPush(d, title, body, url)); return; }
  // iOS Safari: keep the options minimal (renotify / vibrate are not supported there and can make the whole call fail → generic "Notification")
  const show = self.registration.showNotification(title, { body, tag, icon: './icons/icon-192.png', badge: './icons/icon-192.png', data: { url } })
    .catch(() => self.registration.showNotification(title, { body }));
  const badge = (async () => { try { if (!('setAppBadge' in navigator)) return; const c = await caches.open('nf-badge'); const r = await c.match('count'); let n = r ? parseInt(await r.text(), 10) || 0 : 0; n++; await c.put('count', new Response(String(n))); await navigator.setAppBadge(n); } catch (x) { /* ignore */ } })();
  e.waitUntil(Promise.all([show, badge]).catch(() => { }));
});
self.addEventListener('message', e => { const d = e.data || {}; if (d.nfBadge != null) { (async () => { try { const c = await caches.open('nf-badge'); await c.put('count', new Response(String(d.nfBadge))); if ('setAppBadge' in navigator) { if (d.nfBadge > 0) await navigator.setAppBadge(d.nfBadge); else await navigator.clearAppBadge(); } } catch (x) { /* ignore */ } })(); } });
self.addEventListener('notificationclick', e => {
  /* v7.71: the owner's support notice opens the Claude chat itself (claude.ai links only), not the app */
  try { const u0 = String((e.notification.data && e.notification.data.url) || ''); const m0 = /#\/supgo\/([^?#]+)/.exec(u0); if (m0) { const t0 = decodeURIComponent(m0[1]); if (/^https:\/\/claude\.ai\/[A-Za-z0-9_.\/-]+$/.test(t0)) { e.notification.close(); e.waitUntil(self.clients.openWindow(t0)); return; } } } catch (x) { /* fall through to the app */ }
  e.notification.close(); try { caches.open('nf-badge').then(c => c.put('count', new Response('0'))); if ('clearAppBadge' in navigator) navigator.clearAppBadge(); } catch (x) { /* ignore */ } let url = (e.notification.data && e.notification.data.url) || './'; if (e.notification.data && e.notification.data.call && (e.action === 'accept' || e.action === 'decline')) url = './#/calls/' + e.notification.data.call + '/' + e.action;
  /* v6.86: iOS rejects WindowClient.navigate() asynchronously (the old try/catch never caught it, so a tapped notification just
     brought the app forward without opening its page) — the page itself now sets the hash from the message; navigate is not used */
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cs => { for (const c of cs) { if ('focus' in c) { try { c.postMessage({ nfOpen: url }); } catch (x) { /* ignore */ } return c.focus().catch(() => { }); } } return self.clients.openWindow(url); }));
});
