// Ninety Studioz — door bridge for the office server (Node.js 18+, no packages needed).
// Waits for door commands from the Ninety Studioz system and sends them to the Hikvision door station on the office LAN
// (ISAPI, digest auth). Nothing on the router has to be opened: this program only makes outgoing HTTPS calls.
// The key below is unique to this office; downloading the program again from Settings → Door makes a new key.
'use strict';
const TOKEN = '__DOOR_TOKEN__';
const URL_ = '__DOOR_URL__';
const OPEN_PATH = process.env.DOOR_OPEN_PATH || '/ISAPI/AccessControl/RemoteControl/door/1';
const crypto = require('crypto'); const fs = require('fs'); const path = require('path');
const LOG = path.join(__dirname, 'door-bridge.log');
function log(...a) { const line = new Date().toISOString() + ' ' + a.map(x => typeof x === 'string' ? x : JSON.stringify(x)).join(' '); console.log(line); try { fs.appendFileSync(LOG, line + '\n'); const st = fs.statSync(LOG); if (st.size > 2e6) fs.renameSync(LOG, LOG + '.old'); } catch (e) { /* ignore */ } }
const sleep = ms => new Promise(r => setTimeout(r, ms));
const md5 = s => crypto.createHash('md5').update(s).digest('hex');

async function api(body) {
  const r = await fetch(URL_, { method: 'POST', headers: { 'content-type': 'application/json', 'x-bridge-token': TOKEN }, body: JSON.stringify(body), signal: AbortSignal.timeout(40000) });
  const j = await r.json().catch(() => ({})); if (!r.ok) throw new Error('server ' + r.status + ' ' + (j.error || '')); return j;
}
/* HTTP digest auth against the door station */
async function isapi(door, method, uri, body, type) {
  const url = 'http://' + door.ip + uri; const headers = { 'content-type': type || 'application/xml' };
  let r = await fetch(url, { method, headers, body, signal: AbortSignal.timeout(8000) });
  if (r.status === 401) {
    const h = r.headers.get('www-authenticate') || ''; const p = {}; h.replace(/(\w+)="?([^",]+)"?/g, (_, k, v) => { p[k] = v; return ''; });
    const nc = '00000001', cnonce = crypto.randomBytes(8).toString('hex'), qop = (p.qop || 'auth').split(',')[0].trim();
    const ha1 = md5(`${door.user}:${p.realm}:${door.pass}`), ha2 = md5(`${method}:${uri}`);
    const resp = p.qop ? md5(`${ha1}:${p.nonce}:${nc}:${cnonce}:${qop}:${ha2}`) : md5(`${ha1}:${p.nonce}:${ha2}`);
    let auth = `Digest username="${door.user}", realm="${p.realm}", nonce="${p.nonce}", uri="${uri}", response="${resp}"`;
    if (p.qop) auth += `, qop=${qop}, nc=${nc}, cnonce="${cnonce}"`; if (p.opaque) auth += `, opaque="${p.opaque}"`;
    r = await fetch(url, { method, headers: { ...headers, Authorization: auth }, body, signal: AbortSignal.timeout(8000) });
  }
  const text = await r.text(); return { ok: r.ok, status: r.status, text: text.slice(0, 400) };
}
async function openDoor(door) {
  const x = await isapi(door, 'PUT', OPEN_PATH, '<?xml version="1.0" encoding="UTF-8"?><RemoteControlDoor><cmd>open</cmd></RemoteControlDoor>');
  if (!x.ok) throw new Error('door ' + x.status + ' ' + x.text.replace(/\s+/g, ' ').slice(0, 160)); return 'ok';
}
async function syncCards(door, payload) {
  let ok = 0, bad = 0; const errs = [];
  for (const u of (payload.del || [])) { const x = await isapi(door, 'PUT', '/ISAPI/AccessControl/UserInfo/Delete?format=json', JSON.stringify({ UserInfoDelCond: { EmployeeNoList: [{ employeeNo: u.employeeNo }] } }), 'application/json'); x.ok ? ok++ : (bad++, errs.push('del ' + x.status)); }
  for (const u of (payload.set || [])) {
    const a = await isapi(door, 'PUT', '/ISAPI/AccessControl/UserInfo/SetUp?format=json', JSON.stringify({ UserInfo: { employeeNo: u.employeeNo, name: u.name, userType: 'normal', Valid: { enable: true, beginTime: '2024-01-01T00:00:00', endTime: '2037-12-31T23:59:59' }, doorRight: '1', RightPlan: [{ doorNo: 1, planTemplateNo: '1' }] } }), 'application/json');
    const b = a.ok ? await isapi(door, 'PUT', '/ISAPI/AccessControl/CardInfo/SetUp?format=json', JSON.stringify({ CardInfo: { employeeNo: u.employeeNo, cardNo: u.cardNo, cardType: 'normalCard' } }), 'application/json') : a;
    b.ok ? ok++ : (bad++, errs.push(u.name + ' ' + b.status));
  }
  if (bad) throw new Error(`${ok} ok, ${bad} failed: ${errs.slice(0, 4).join('; ')}`); return `${ok} ok`;
}
async function main() {
  if (/__DOOR_/.test(TOKEN + URL_)) { log('This file has no office key — download it from Settings → Door.'); process.exit(1); }
  log('door bridge started'); try { const h = await api({ action: 'hello' }); log('connected', h); } catch (e) { log('hello failed', String(e.message || e)); }
  let wait = 1000;
  for (;;) {
    try {
      const j = await api({ action: 'next' }); wait = 1000;
      for (const c of (j.cmds || [])) {
        let ok = false, detail = '';
        try {
          if (!j.door || !j.door.ip || !j.door.pass) throw new Error('door station details not saved in Settings → Door');
          detail = c.kind === 'cards' ? await syncCards(j.door, c.payload || {}) : await openDoor(j.door); ok = true;
        } catch (e) { detail = String(e.message || e); }
        log(c.kind, '#' + c.id, ok ? 'ok' : 'FAILED', detail);
        try { await api({ action: 'done', id: c.id, ok, detail }); } catch (e) { log('report failed', String(e.message || e)); }
      }
    } catch (e) { log('server unreachable, retrying', String(e.message || e)); await sleep(wait); wait = Math.min(wait * 2, 30000); }
  }
}
process.on('unhandledRejection', e => log('unhandled', String(e && e.message || e)));
main();
