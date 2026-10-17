# Ninety Android — applies the app settings to the freshly generated Capacitor Android project (run after `npx cap add android`).
# Signing: /tmp/signing.json comes from the factory Edge function "app-build" (action signing), which hands the existing
# Ninety signing key only to a running Codemagic build of this app. Nothing secret is stored in the repo or printed in the log.
import base64, json, os, re
APP = 'android/app'
GRADLE = APP + '/build.gradle'
MANIFEST = APP + '/src/main/AndroidManifest.xml'
build_no = int(os.environ.get('BUILD_NUMBER', '0') or 0)
version_code = 100 + build_no          # above the old Ninety.apk / Play bundle (version codes 1–3)
version_name = '2.0.%d' % build_no

sig = {}
try:
    sig = json.load(open('/tmp/signing.json'))
except Exception:
    pass
if not sig.get('ok'):
    raise SystemExit('signing key not available (error: %s)' % sig.get('error', 'none'))
open(APP + '/ninety.jks', 'wb').write(base64.b64decode(sig['keystore']))
open('android/keystore.properties', 'w').write('storeFile=ninety.jks\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n' % (sig['storePass'], sig.get('alias', 'ninety'), sig['keyPass']))
if sig.get('gservices'):
    open(APP + '/google-services.json', 'w').write(sig['gservices'])
    print('google-services.json added (Android notifications on)')
else:
    print('no google-services.json yet (Android notifications off until it is uploaded)')

g = open(GRADLE).read()
g = re.sub(r'versionCode\s+\d+', 'versionCode %d' % version_code, g)
g = re.sub(r'versionName\s+"[^"]*"', 'versionName "%s"' % version_name, g)
if 'keystoreProperties' not in g:
    g = g.replace('android {', '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('keystore.properties')
if (keystorePropertiesFile.exists()) { keystoreProperties.load(new FileInputStream(keystorePropertiesFile)) }

android {
    signingConfigs {
        release {
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
        }
    }''', 1)
    g = re.sub(r'(buildTypes\s*\{\s*release\s*\{)', r'\1\n            signingConfig signingConfigs.release', g, count=1)
open(GRADLE, 'w').write(g)

m = open(MANIFEST).read()
if 'android.permission.POST_NOTIFICATIONS' not in m:
    m = m.replace('<uses-permission android:name="android.permission.INTERNET" />', '<uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />\n    <uses-permission android:name="android.permission.NFC" />\n    <uses-permission android:name="android.permission.USE_BIOMETRIC" />\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />\n    <uses-permission android:name="android.permission.WAKE_LOCK" />')
m = m.replace('android:allowBackup="true"', 'android:allowBackup="false"')
# v7.11 calls: the Ninety calls plugin takes the Firebase messages first (calls → call screen, the rest → Capacitor as before)
if 'xmlns:tools=' not in m:
    m = m.replace('xmlns:android="http://schemas.android.com/apk/res/android"', 'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"', 1)
if 'pushnotifications.MessagingService' not in m:
    m = m.replace('</application>', '    <service android:name="com.capacitorjs.plugins.pushnotifications.MessagingService" tools:node="remove" />\n    </application>', 1)
# v7.57: «Share» → Ninety (images / PDF) opens the app on «Send to a task» (plugin ninety-share takes the files)
if 'android.intent.action.SEND' not in m:
    share = '''
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="application/pdf" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>'''
    i = m.find('android.intent.category.LAUNCHER')
    j = m.find('</intent-filter>', i) if i >= 0 else -1
    if j >= 0:
        j += len('</intent-filter>')
        m = m[:j] + share + m[j:]
        print('share intents added')
open(MANIFEST, 'w').write(m)

strings = APP + '/src/main/res/values/strings.xml'
s = open(strings).read()
if 'capacitor_background_geolocation_notification_channel_name' not in s:
    s = s.replace('</resources>', '    <string name="capacitor_background_geolocation_notification_channel_name">Trip tracking</string>\n</resources>')
open(strings, 'w').write(s)
print('android configured: versionCode %d, versionName %s' % (version_code, version_name))
