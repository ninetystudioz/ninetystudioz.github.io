package app.ninety.calls;

import android.annotation.SuppressLint;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.getcapacitor.JSObject;

/**
 * Ninety v7.36 — the self-update result.
 * · app.ninety.calls.UPDATE_STATUS (from PackageInstaller): «confirm» opens Android's «Update this app?» screen (only the first
 *   time, or on Android below 12), «done» / «aborted» / «failed» go back to the page as the «updateStatus» event.
 * · MY_PACKAGE_REPLACED: the new version is installed (Android closes the app for that) → a notification «Ninety updated — tap to open».
 */
public class UpdateReceiver extends BroadcastReceiver {
    static final String CH_APP = "nf_app_update";
    private static Intent pendingConfirm;

    static synchronized Intent takeConfirm() {
        Intent i = pendingConfirm;
        pendingConfirm = null;
        return i;
    }

    private static synchronized void keepConfirm(Intent i) {
        pendingConfirm = i;
    }

    @Override
    public void onReceive(Context c, Intent intent) {
        if (intent == null) return;
        if (Intent.ACTION_MY_PACKAGE_REPLACED.equals(intent.getAction())) {
            NinetyCallsPlugin.updateFinished();
            updatedNote(c);
            return;
        }
        int status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
        String msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
        JSObject o = new JSObject();
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirm = confirmIntent(intent);
            if (confirm != null) {
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                boolean shown = false;
                if (NinetyCallsPlugin.inFront()) {
                    try { c.startActivity(confirm); shown = true; } catch (Exception ignored) { }
                }
                if (!shown) keepConfirm(confirm);   /* opens when the app comes back to the screen */
            }
            o.put("status", "confirm");
        } else if (status == PackageInstaller.STATUS_SUCCESS) {
            takeConfirm();
            NinetyCallsPlugin.updateFinished();
            o.put("status", "done");
        } else {
            takeConfirm();
            NinetyCallsPlugin.updateFinished();
            o.put("status", status == PackageInstaller.STATUS_FAILURE_ABORTED ? "aborted" : "failed");
            o.put("code", status);
            o.put("message", msg == null ? "" : msg);
        }
        NinetyCallsPlugin p = NinetyCallsPlugin.self;
        if (p != null) p.emitUpdate(o);
    }

    @SuppressWarnings("deprecation")
    private static Intent confirmIntent(Intent intent) {
        try {
            if (Build.VERSION.SDK_INT >= 33) return intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent.class);
            return (Intent) intent.getParcelableExtra(Intent.EXTRA_INTENT);
        } catch (Exception e) {
            return null;
        }
    }

    @SuppressLint("MissingPermission")
    private static void updatedNote(Context c) {
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
                if (nm != null && nm.getNotificationChannel(CH_APP) == null) {
                    nm.createNotificationChannel(new NotificationChannel(CH_APP, CallUI.tr(c, "تحديث الأبلكيشن", "App updates"), NotificationManager.IMPORTANCE_DEFAULT));
                }
            }
            Intent launch = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
            if (launch == null) return;
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            PendingIntent pi = PendingIntent.getActivity(c, 0x4e5550, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            NotificationCompat.Builder b = new NotificationCompat.Builder(c, CH_APP)
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setContentTitle(CallUI.tr(c, "Ninety اتحدّث ✓", "Ninety updated ✓"))
                    .setContentText(CallUI.tr(c, "دوس علشان تفتحه", "Tap to open it"))
                    .setAutoCancel(true)
                    .setContentIntent(pi);
            NotificationManagerCompat.from(c).notify(0x4e5550, b.build());
        } catch (Exception ignored) { }
    }
}
