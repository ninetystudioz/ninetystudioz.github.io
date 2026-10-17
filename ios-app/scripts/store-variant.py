# Ninety Android — the Play Store bundle (.aab) must not update itself (Play updates it): after the website APK is built,
# the self-update install permission is dropped from the app manifest, then the bundle is built (run from ios-app/).
M = 'android/app/src/main/AndroidManifest.xml'
m = open(M).read()
tag = '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />'
if 'xmlns:tools=' not in m:
    m = m.replace('xmlns:android="http://schemas.android.com/apk/res/android"', 'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"', 1)
if tag not in m:
    m = m.replace('<application', '    ' + tag + '\n    <application', 1) if m.count('<application') else m
open(M, 'w').write(m)
print('store bundle: self-update permission removed' if tag in m else 'store bundle: manifest not changed')
