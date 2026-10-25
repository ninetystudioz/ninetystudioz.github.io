package app.ninety.calls;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

import androidx.core.app.NotificationCompat;

/**
 * v8.69 «call in progress»: while a LiveKit call runs in the app (NinetyLK) a small fixed notification keeps the microphone and the
 * call alive with the screen off or the app in the background (Android needs a microphone foreground service for that).
 * Started by lkJoin (the app is open on the call screen), stopped when the last room is left.
 */
public class CallService extends Service {
    static final String CH_CALL = "nf_call_live";
    static final int NID = 0x4e4c;

    static void start(Context c) {
        try {
            Intent i = new Intent(c, CallService.class);
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i);
            else c.startService(i);
        } catch (Exception ignored) {
            /* not allowed right now (app in the background on Android 12+) — the call still runs while the app is open */
        }
    }

    static void stop(Context c) {
        try { c.stopService(new Intent(c, CallService.class)); } catch (Exception ignored) { }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && nm.getNotificationChannel(CH_CALL) == null) {
                NotificationChannel ch = new NotificationChannel(CH_CALL, CallUI.tr(this, "مكالمة شغّالة", "Call in progress"), NotificationManager.IMPORTANCE_LOW);
                ch.setShowBadge(false);
                ch.setSound(null, null);
                nm.createNotificationChannel(ch);
            }
        }
        Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (open == null) open = new Intent();
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(this, NID, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification n = new NotificationCompat.Builder(this, CH_CALL)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle(CallUI.tr(this, "مكالمة شغّالة", "Call in progress"))
                .setContentText(CallUI.tr(this, "اضغط علشان ترجع للمكالمة", "Tap to return to the call"))
                .setOngoing(true)
                .setUsesChronometer(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setContentIntent(pi)
                .build();
        try {
            if (Build.VERSION.SDK_INT >= 30) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
            else startForeground(NID, n);
        } catch (Exception e) {
            stopSelf();
            return START_NOT_STICKY;
        }
        if (NinetyLK.count() == 0) stopSelf();   /* the call ended meanwhile */
        return START_NOT_STICKY;
    }
}
