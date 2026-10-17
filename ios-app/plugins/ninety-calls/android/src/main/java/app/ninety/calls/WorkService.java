package app.ninety.calls;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

import androidx.core.app.NotificationCompat;

/**
 * «Work mode»: from the punch-in to the punch-out (or one hour after the shift end) a small fixed notification keeps
 * the app process alive, so call messages are never held back by the battery saver. Stops by itself at «until».
 */
public class WorkService extends Service {
    static final String CH_WORK = "nf_work";
    static final int NID = 0x4e45;
    private static final String PREFS = "nfcalls";
    private final Handler h = new Handler(Looper.getMainLooper());

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        SharedPreferences sp = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String title;
        String text;
        long until;
        if (intent != null && intent.hasExtra("until")) {
            title = intent.getStringExtra("title");
            text = intent.getStringExtra("text");
            until = intent.getLongExtra("until", 0L);
            sp.edit().putString("w_title", title).putString("w_text", text).putLong("w_until", until).apply();
        } else {
            /* restarted by the system after it was killed */
            title = sp.getString("w_title", "Ninety");
            text = sp.getString("w_text", "");
            until = sp.getLong("w_until", 0L);
        }
        if (title == null || title.isEmpty()) title = "Ninety";
        if (text == null) text = "";
        long left = until - System.currentTimeMillis();
        if (until <= 0 || left <= 0) {
            startFg(title, text);
            stopSelf();
            return START_NOT_STICKY;
        }
        startFg(title, text);
        h.removeCallbacksAndMessages(null);
        h.postDelayed(this::stopSelf, left);
        return START_STICKY;
    }

    private void startFg(String title, String text) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && nm.getNotificationChannel(CH_WORK) == null) {
                NotificationChannel ch = new NotificationChannel(CH_WORK, CallUI.tr(this, "وضع الشغل", "Work mode"), NotificationManager.IMPORTANCE_LOW);
                ch.setShowBadge(false);
                nm.createNotificationChannel(ch);
            }
        }
        Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (open == null) open = new Intent();
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(this, NID, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification n = new NotificationCompat.Builder(this, CH_WORK)
                .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setContentIntent(pi)
                .build();
        try {
            if (Build.VERSION.SDK_INT >= 34) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING);
            else startForeground(NID, n);
        } catch (Exception e) {
            /* not allowed right now (e.g. started from the background on Android 12+) — nothing else to do */
            stopSelf();
        }
    }

    @Override
    public void onDestroy() {
        h.removeCallbacksAndMessages(null);
        super.onDestroy();
    }
}
