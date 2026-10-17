package app.ninety.calls;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Ninety — the app side of the native call screen (JS name «NinetyCalls»).
 * pending() / «callAction» event: what was pressed on the call screen while the page was not there (answer / open).
 * endCall(): the in-app call took over → stop the ringing screen. startWork()/stopWork(): the work-mode foreground service.
 * v7.36 (versionCode 104+): info() — this app's version; update({url}) — download the new Ninety.apk from the site and install it
 * over this one (PackageInstaller; the first time Android asks once, later updates go through by themselves on Android 12+);
 * «updateProgress» / «updateStatus» events; openSettings({kind}) — the phone settings that make calls ring
 * (notifications · channel · fullscreen · battery · autostart · install · app).
 */
@CapacitorPlugin(name = "NinetyCalls")
public class NinetyCallsPlugin extends Plugin {

    static NinetyCallsPlugin self;
    private static volatile boolean updating = false;
    private static volatile boolean front = false;

    static boolean inFront() {
        return front;
    }

    @Override
    public void load() {
        self = this;
        if (getActivity() != null && getActivity().getIntent() != null) takeIntent(getActivity().getIntent());
    }

    @Override
    protected void handleOnNewIntent(Intent intent) {
        super.handleOnNewIntent(intent);
        if (intent != null) takeIntent(intent);
    }

    @Override
    protected void handleOnResume() {
        super.handleOnResume();
        front = true;
        /* an install confirmation that could not open while the app was in the background */
        Intent confirm = UpdateReceiver.takeConfirm();
        if (confirm != null && getActivity() != null) {
            try { getActivity().startActivity(confirm); } catch (Exception ignored) { }
        }
    }

    @Override
    protected void handleOnPause() {
        super.handleOnPause();
        front = false;
    }

    /** used by UpdateReceiver (notifyListeners is protected) */
    void emitUpdate(JSObject o) {
        notifyListeners("updateStatus", o, true);
    }

    static void updateFinished() {
        updating = false;
    }

    private void takeIntent(Intent intent) {
        String action = intent.getStringExtra(CallUI.EXTRA_ACTION);
        if (action == null) return;
        String callId = intent.getStringExtra(CallUI.EXTRA_CALL_ID);
        String url = intent.getStringExtra(CallUI.EXTRA_URL);
        intent.removeExtra(CallUI.EXTRA_ACTION);
        if (callId != null) CallUI.stop(getContext(), callId);
        CallUI.setPending(getContext(), action, callId, url);
        JSObject o = new JSObject();
        o.put("action", action);
        o.put("callId", callId == null ? "" : callId);
        o.put("url", url == null ? "" : url);
        notifyListeners("callAction", o, true);
    }

    @PluginMethod
    public void voipToken(PluginCall call) {
        JSObject o = new JSObject();
        o.put("token", "");
        call.resolve(o);
    }

    @PluginMethod
    public void pending(PluginCall call) {
        call.resolve(CallUI.takePending(getContext()));
    }

    @PluginMethod
    public void endCall(PluginCall call) {
        String id = call.getString("callId", "");
        if (id != null && !id.isEmpty()) CallUI.stop(getContext(), id);
        call.resolve();
    }

    @PluginMethod
    public void startWork(PluginCall call) {
        Context c = getContext();
        Intent i = new Intent(c, WorkService.class);
        i.putExtra("title", call.getString("title", "Ninety"));
        i.putExtra("text", call.getString("text", ""));
        Double until = call.getDouble("until");
        i.putExtra("until", until == null ? 0L : until.longValue());
        try {
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i); else c.startService(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("start_failed", e);
        }
    }

    @PluginMethod
    public void stopWork(PluginCall call) {
        getContext().stopService(new Intent(getContext(), WorkService.class));
        call.resolve();
    }

    @PluginMethod
    public void permState(PluginCall call) {
        Context c = getContext();
        boolean battery = true;
        PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
        if (pm != null) battery = pm.isIgnoringBatteryOptimizations(c.getPackageName());
        boolean fullScreen = true;
        if (Build.VERSION.SDK_INT >= 34) {
            NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) fullScreen = nm.canUseFullScreenIntent();
        }
        boolean notif = true;
        NotificationManager nm2 = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm2 != null && Build.VERSION.SDK_INT >= 24) notif = nm2.areNotificationsEnabled();
        JSObject o = new JSObject();
        o.put("battery", battery);
        o.put("fullScreen", fullScreen);
        o.put("notifications", notif);
        o.put("canInstall", canInstall(c));
        call.resolve(o);
    }

    @PluginMethod
    public void requestIgnoreBattery(PluginCall call) {
        openBattery(getContext());
        call.resolve();
    }

    @PluginMethod
    public void openFullScreenSettings(PluginCall call) {
        openFullScreen(getContext());
        call.resolve();
    }

    /* ---------------- v7.36: version + self-update ---------------- */

    /** the website APK declares the install permission; the Play Store bundle does not (Play updates it) */
    private static boolean declaresInstall(Context c) {
        try {
            PackageInfo pi = c.getPackageManager().getPackageInfo(c.getPackageName(), PackageManager.GET_PERMISSIONS);
            if (pi.requestedPermissions != null) {
                for (String p : pi.requestedPermissions) if ("android.permission.REQUEST_INSTALL_PACKAGES".equals(p)) return true;
            }
        } catch (Exception ignored) { }
        return false;
    }

    @SuppressWarnings("deprecation")
    private static boolean fromPlay(Context c) {
        try {
            String inst = Build.VERSION.SDK_INT >= 30
                    ? c.getPackageManager().getInstallSourceInfo(c.getPackageName()).getInstallingPackageName()
                    : c.getPackageManager().getInstallerPackageName(c.getPackageName());
            return "com.android.vending".equals(inst);
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean selfUpdate(Context c) {
        return declaresInstall(c) && !fromPlay(c);
    }

    private static boolean canInstall(Context c) {
        if (Build.VERSION.SDK_INT < 26) return true;
        try { return c.getPackageManager().canRequestPackageInstalls(); } catch (Exception e) { return false; }
    }

    @PluginMethod
    @SuppressWarnings("deprecation")
    public void info(PluginCall call) {
        Context c = getContext();
        JSObject o = new JSObject();
        try {
            PackageInfo pi = c.getPackageManager().getPackageInfo(c.getPackageName(), 0);
            long vc = Build.VERSION.SDK_INT >= 28 ? pi.getLongVersionCode() : (long) pi.versionCode;
            o.put("versionCode", vc);
            o.put("versionName", pi.versionName == null ? "" : pi.versionName);
        } catch (Exception e) {
            o.put("versionCode", 0);
            o.put("versionName", "");
        }
        o.put("canInstall", canInstall(c));
        o.put("selfUpdate", selfUpdate(c));
        o.put("updating", updating);
        o.put("sdk", Build.VERSION.SDK_INT);
        o.put("make", Build.MANUFACTURER == null ? "" : Build.MANUFACTURER);
        o.put("model", Build.MODEL == null ? "" : Build.MODEL);
        call.resolve(o);
    }

    private static boolean allowedUrl(String url) {
        try {
            URL u = new URL(url);
            if (!"https".equals(u.getProtocol())) return false;
            String h = u.getHost();
            return "ninetystudioz.github.io".equals(h) || "mahmoudfawzy1212mf-crypto.github.io".equals(h) || "raw.githubusercontent.com".equals(h);
        } catch (Exception e) {
            return false;
        }
    }

    @PluginMethod
    public void update(PluginCall call) {
        final Context c = getContext();
        final String url = call.getString("url", "");
        if (url == null || !allowedUrl(url)) { call.reject("bad_url"); return; }
        if (!selfUpdate(c)) { call.reject("store_build"); return; }
        if (!canInstall(c)) {
            openInstallSettings(c);
            JSObject o = new JSObject();
            o.put("status", "permission");
            call.resolve(o);
            return;
        }
        if (updating) {
            JSObject o = new JSObject();
            o.put("status", "busy");
            call.resolve(o);
            return;
        }
        updating = true;
        new Thread(() -> {
            HttpURLConnection conn = null;
            PackageInstaller.Session session = null;
            int sid = -1;
            try {
                conn = (HttpURLConnection) new URL(url).openConnection();
                conn.setConnectTimeout(20000);
                conn.setReadTimeout(60000);
                conn.setInstanceFollowRedirects(true);
                conn.setRequestProperty("Cache-Control", "no-cache");
                conn.setRequestProperty("Accept-Encoding", "identity");   /* the exact APK size, no gzip */
                int code = conn.getResponseCode();
                if (code != 200) throw new Exception("http " + code);
                long total = conn.getContentLengthLong();
                PackageInstaller installer = c.getPackageManager().getPackageInstaller();
                PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                params.setAppPackageName(c.getPackageName());
                if (total > 0) params.setSize(total);
                if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED);
                sid = installer.createSession(params);
                session = installer.openSession(sid);
                long done = 0;
                long lastEmit = 0;
                try (InputStream in = conn.getInputStream(); OutputStream out = session.openWrite("ninety.apk", 0, total > 0 ? total : -1)) {
                    byte[] buf = new byte[65536];
                    int n;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                        done += n;
                        long now = System.currentTimeMillis();
                        if (now - lastEmit > 400) {
                            lastEmit = now;
                            JSObject p = new JSObject();
                            p.put("done", done);
                            p.put("total", total);
                            notifyListeners("updateProgress", p, false);
                        }
                    }
                    session.fsync(out);
                }
                if (done < 100000) throw new Exception("tiny download");
                JSObject p = new JSObject();
                p.put("done", done);
                p.put("total", total > 0 ? total : done);
                notifyListeners("updateProgress", p, false);
                Intent i = new Intent(c, UpdateReceiver.class);
                i.setAction("app.ninety.calls.UPDATE_STATUS");
                int flags = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
                PendingIntent pi = PendingIntent.getBroadcast(c, sid, i, flags);
                session.commit(pi.getIntentSender());
                session.close();
                session = null;
                JSObject o = new JSObject();
                o.put("status", "installing");
                o.put("bytes", done);
                call.resolve(o);
            } catch (Exception e) {
                updating = false;
                if (session != null) { try { session.abandon(); } catch (Exception ignored) { } }
                call.reject("update_failed: " + e.getMessage());
            } finally {
                if (conn != null) conn.disconnect();
            }
        }).start();
    }

    /* ---------------- v7.36: phone settings for calls ---------------- */

    @PluginMethod
    public void openSettings(PluginCall call) {
        Context c = getContext();
        String kind = call.getString("kind", "app");
        boolean ok;
        if ("notifications".equals(kind)) ok = openNotifications(c, null);
        else if ("channel".equals(kind)) ok = openNotifications(c, call.getString("channel", "nf_calls"));
        else if ("fullscreen".equals(kind)) ok = openFullScreen(c);
        else if ("battery".equals(kind)) ok = openBattery(c);
        else if ("autostart".equals(kind)) ok = openAutostart(c) || openAppDetails(c);
        else if ("install".equals(kind)) ok = openInstallSettings(c);
        else ok = openAppDetails(c);
        JSObject o = new JSObject();
        o.put("opened", ok);
        call.resolve(o);
    }

    private static boolean start(Context c, Intent i) {
        try {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean openAppDetails(Context c) {
        return start(c, new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + c.getPackageName())));
    }

    private static boolean openNotifications(Context c, String channel) {
        if (Build.VERSION.SDK_INT >= 26) {
            if (channel != null && !channel.isEmpty()) {
                Intent ch = new Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS);
                ch.putExtra(Settings.EXTRA_APP_PACKAGE, c.getPackageName());
                ch.putExtra(Settings.EXTRA_CHANNEL_ID, channel);
                if (start(c, ch)) return true;
            }
            Intent i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            i.putExtra(Settings.EXTRA_APP_PACKAGE, c.getPackageName());
            if (start(c, i)) return true;
        }
        return openAppDetails(c);
    }

    private static boolean openFullScreen(Context c) {
        if (Build.VERSION.SDK_INT >= 34) {
            if (start(c, new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:" + c.getPackageName())))) return true;
        }
        return openNotifications(c, null);
    }

    private static boolean openBattery(Context c) {
        PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
        boolean ignoring = pm != null && pm.isIgnoringBatteryOptimizations(c.getPackageName());
        if (!ignoring) {
            if (start(c, new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + c.getPackageName())))) return true;
            if (start(c, new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return true;
        }
        return openAutostart(c) || openAppDetails(c);
    }

    /** the maker's own «auto-start / background» screen (Xiaomi, Oppo/Realme, Vivo, Huawei/Honor, Samsung) */
    private static boolean openAutostart(Context c) {
        String[][] screens = {
            {"com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"},
            {"com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"},
            {"com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"},
            {"com.oplus.safecenter", "com.oplus.safecenter.startupapp.StartupAppListActivity"},
            {"com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"},
            {"com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"},
            {"com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"},
            {"com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"},
            {"com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"},
            {"com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"},
            {"com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"},
            {"com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"}
        };
        /* no resolveActivity() here: from Android 11 other apps' screens are invisible to it without <queries> — just try them */
        for (String[] s : screens) {
            Intent i = new Intent();
            i.setClassName(s[0], s[1]);
            if (start(c, i)) return true;
        }
        return false;
    }

    private static boolean openInstallSettings(Context c) {
        if (Build.VERSION.SDK_INT >= 26) {
            if (start(c, new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + c.getPackageName())))) return true;
        }
        return openAppDetails(c);
    }
}
