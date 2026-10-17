# Ninety iOS — applies the app settings to the freshly generated Capacitor iOS project (run after `npx cap add ios`).
import plistlib
INFO = 'ios/App/App/Info.plist'; PBX = 'ios/App/App.xcodeproj/project.pbxproj'; DELEGATE = 'ios/App/App/AppDelegate.swift'
TEAM = 'UF4QLJ9AY9'
d = plistlib.load(open(INFO, 'rb'))
d.update({
    'CFBundleDisplayName': 'Ninety',
    'CFBundleDevelopmentRegion': 'ar', 'CFBundleLocalizations': ['ar', 'en'],
    'NSCameraUsageDescription': 'Ninety uses the camera to take work photos, receipts and your profile picture.',
    'NSPhotoLibraryUsageDescription': 'Ninety lets you attach photos from your library to tasks and requests.',
    'NSPhotoLibraryAddUsageDescription': 'Ninety saves files you export (reports, PDFs) to your photo library.',
    'NSLocationWhenInUseUsageDescription': 'Ninety checks your location when you punch in or out, confirm arrival at an errand, and records the route of a delivery trip you started.',
    'NSLocationAlwaysAndWhenInUseUsageDescription': 'During a delivery trip you started, Ninety keeps recording the route while the phone is locked, so the fleet manager sees the truck live. Recording stops when you finish the trip.',
    'NSMicrophoneUsageDescription': 'Ninety uses the microphone for team calls and voice notes.',
    'NSFaceIDUsageDescription': 'Ninety uses Face ID to confirm it is you when you punch in.',
    'NFCReaderUsageDescription': 'Ninety reads the office door NFC sticker to open the door.',
    'ITSAppUsesNonExemptEncryption': False,
    'UIBackgroundModes': ['remote-notification', 'location', 'voip', 'audio'],
    'UIRequiredDeviceCapabilities': ['arm64'],
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    # v7.48: the app runs natively on iPad too (Apple Pencil in Concept) — the iPad turns every way, the iPhone stays upright
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
})
plistlib.dump(d, open(INFO, 'wb'))
open('ios/App/App/App.entitlements', 'w').write('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>production</string>
	<key>com.apple.developer.nfc.readersession.formats</key>
	<array>
		<string>TAG</string>
	</array>
</dict>
</plist>
''')
s = open(PBX).read()
# v7.48: iPhone + iPad (was iPhone only: TARGETED_DEVICE_FAMILY = 1)
s = s.replace('TARGETED_DEVICE_FAMILY = 1;', 'TARGETED_DEVICE_FAMILY = "1,2";')
if 'CODE_SIGN_ENTITLEMENTS' not in s:
    s = s.replace('PRODUCT_BUNDLE_IDENTIFIER = app.ninety.fabrication;', 'PRODUCT_BUNDLE_IDENTIFIER = app.ninety.fabrication;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = App/App.entitlements;\n\t\t\t\tDEVELOPMENT_TEAM = %s;' % TEAM)
open(PBX, 'w').write(s)
a = open(DELEGATE).read()
if 'capacitorDidRegisterForRemoteNotifications' not in a:
    a = a.rstrip().rstrip('}') + '''
    // push: hand the APNs token to the Capacitor push plugin
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }
}
'''
    open(DELEGATE, 'w').write(a)
# v7.11 calls: start the PushKit / CallKit side at launch (by class name — the plugin module needs no import here),
# so a call that wakes the closed app shows the iPhone call screen at once
a = open(DELEGATE).read()
if 'NinetyCallBoot' not in a:
    i = a.find('didFinishLaunchingWithOptions')
    j = a.find('return true', i)
    if i < 0 or j < 0:
        raise SystemExit('AppDelegate: didFinishLaunching not found')
    boot = '(NSClassFromString("NinetyCallsPlugin.NinetyCallBoot") as AnyObject?)?.perform(NSSelectorFromString("boot"))\n        '
    a = a[:j] + boot + a[j:]
    open(DELEGATE, 'w').write(a)
# v7.48 (note 5): the Apple Pencil plugin (double-tap / squeeze) is an iOS-only package — added here, on the build Mac, so the
# Android build (same package.json) never changes because of it; `npx cap sync ios` (next step) picks it up
import subprocess, json
pk = json.load(open('package.json'))
if 'ninety-pencil' not in pk.get('dependencies', {}):
    subprocess.run(['npm', 'install', '--no-audit', '--no-fund', '--save', 'file:plugins/ninety-pencil'], check=True)
# v7.57: the «Share» extension — only when scripts/share-signing.py installed its profile. The project and the app entitlements
# are kept as they were first, so the build can fall back to the app without the extension (codemagic.yaml, «Build the app»).
import os, shutil
if os.path.exists('/tmp/share-ext-ok'):
    shutil.copy(PBX, '/tmp/pbx.noshare'); shutil.copy('ios/App/App/App.entitlements', '/tmp/ent.noshare')
    if subprocess.run(['ruby', '-e', "require 'xcodeproj'"], capture_output=True).returncode != 0:
        subprocess.run(['gem', 'install', 'xcodeproj', '--no-document', '--user-install'], check=False)
    ok = subprocess.run(['ruby', 'scripts/add-share-ext.rb']).returncode == 0
    if ok:
        e = open('ios/App/App/App.entitlements').read()
        if 'keychain-access-groups' not in e:
            e = e.replace('</dict>\n</plist>', '\t<key>keychain-access-groups</key>\n\t<array>\n\t\t<string>$(AppIdentifierPrefix)app.ninety.shared</string>\n\t</array>\n</dict>\n</plist>')
            open('ios/App/App/App.entitlements', 'w').write(e)
        print('share extension added')
    else:
        shutil.copy('/tmp/pbx.noshare', PBX); os.remove('/tmp/pbx.noshare'); os.remove('/tmp/ent.noshare')
        print('share extension NOT added (the app builds without it)')
print('ios configured')
