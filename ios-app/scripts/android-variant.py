# Ninety Android - four apps from one project (v7.94): sets the app id, the name, the address it opens and the
# icon colour for one variant, before `npx cap add android`. Run from ios-app/: python3 scripts/android-variant.py <variant>
# Writes /tmp/nf-variant.env (NF_APPID, NF_ICON_BG) for the next steps. The web app reads "NinetyApp/<variant>" from
# the user agent to know which app it is running in.
import json, re, sys

BASE = 'https://ninetystudioz.github.io'
VARIANTS = {
    'fabrication':  {'id': 'app.ninety.fabrication',  'name': 'Ninety Fabrication',  'path': '/',              'bg': '#1F3550'},
    'studioz':      {'id': 'app.ninety.studioz',      'name': 'Ninety Studioz',      'path': '/studioz/',      'bg': '#2F3540'},
    'construction': {'id': 'app.ninety.construction', 'name': 'Ninety Construction', 'path': '/construction/', 'bg': '#1F3F3B'},
    'ninety':       {'id': 'app.ninety.hub',          'name': 'Ninety',              'path': '/',              'bg': '#171B1F'},
}
v = (sys.argv[1] if len(sys.argv) > 1 else '').strip().lower()
if v not in VARIANTS:
    raise SystemExit('android-variant: unknown variant %r (one of %s)' % (v, ', '.join(VARIANTS)))
x = VARIANTS[v]
url = BASE + x['path']

cfg = json.load(open('capacitor.config.json'))
cfg['appId'] = x['id']
cfg['appName'] = x['name']
cfg.setdefault('server', {})['url'] = url
cfg['appendUserAgent'] = 'NinetyApp/' + v
cfg.setdefault('android', {})['backgroundColor'] = x['bg'].lower()
json.dump(cfg, open('capacitor.config.json', 'w'), indent=2, ensure_ascii=False)

for page in ('www/index.html', 'www/offline.html'):
    try:
        h = open(page, encoding='utf-8').read()
    except FileNotFoundError:
        continue
    h = re.sub(r"https://ninetystudioz\.github\.io/[^'\"]*", url, h)
    h = h.replace('<title>Ninety</title>', '<title>%s</title>' % x['name'])
    h = re.sub(r'(<b[^>]*>)Ninety(</b>)', r'\g<1>%s\g<2>' % x['name'], h)
    h = h.replace('#171b1f', x['bg'].lower())
    open(page, 'w', encoding='utf-8').write(h)

open('/tmp/nf-variant.env', 'w').write('NF_APPID=%s\nNF_ICON_BG=%s\n' % (x['id'], x['bg']))
print('android variant %s: %s - %s - %s' % (v, x['id'], x['name'], url))
