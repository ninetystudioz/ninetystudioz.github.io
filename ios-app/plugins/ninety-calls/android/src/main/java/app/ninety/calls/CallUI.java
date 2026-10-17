package app.ninety.calls;

import android.annotation.SuppressLint;
import android.app.ActivityManager;
import android.app.KeyguardManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.service.notification.StatusBarNotification;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.Person;

import com.getcapacitor.JSObject;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;

/**
 * Ninety — the Android incoming-call screen, shown from a data-only FCM message (the app may be closed):
 * a full-screen call (lock screen too) with the ringtone, «Answer» opens the app straight on the call,
 * «Decline» tells the server with the per-call token. «stop» / «end» messages close it (end = «missed call» note).
 */
public final class CallUI {
    public static final String EXTRA_ACTION = "nfcall_action";
    public static final String EXTRA_CALL_ID = "nfcall_id";
    public static final String EXTRA_URL = "nfcall_url";
    public static final String ACTION_DECLINE = "app.ninety.calls.DECLINE";
    static final String CH_RING = "nf_calls_ring_v1";
    static final String CH_MISSED = "nf_calls_missed";
    static final String API = "https://erhcnkjyaumdoixkksbz.supabase.co/functions/v1/push";
    static final long RING_MS = 46000L;
    private static final String PREFS = "nfcalls";

    private CallUI() { }

    static int nid(String callId) {
        return 0x4e46 + ((callId == null ? 0 : callId.hashCode()) & 0xffff);
    }

    static boolean arabic(Context c) {
        try {
            Locale l = c.getResources().getConfiguration().getLocales().get(0);
            return l != null && "ar".equals(l.getLanguage());
        } catch (Exception e) {
            return true;
        }
    }

    static String tr(Context c, String ar, String en) {
        return arabic(c) ? ar : en;
    }

    private static void channels(Context c) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        if (nm.getNotificationChannel(CH_RING) == null) {
            NotificationChannel ch = new NotificationChannel(CH_RING, tr(c, "المكالمات الواردة", "Incoming calls"), NotificationManager.IMPORTANCE_HIGH);
            Uri tone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            AudioAttributes aa = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            ch.setSound(tone, aa);
            ch.enableVibration(true);
            ch.setVibrationPattern(new long[]{0, 1000, 800, 1000, 800});
            ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            ch.setBypassDnd(false);
            nm.createNotificationChannel(ch);
        }
        if (nm.getNotificationChannel(CH_MISSED) == null) {
            NotificationChannel ch = new NotificationChannel(CH_MISSED, tr(c, "مكالمات فايتة", "Missed calls"), NotificationManager.IMPORTANCE_DEFAULT);
            nm.createNotificationChannel(ch);
        }
    }

    /** a call message from FCM: type ring | stop | end */
    public static void handle(Context ctx, Map<String, String> d) {
        String type = d.get("type");
        String id = d.get("callId");
        if (id == null || id.isEmpty()) return;
        if ("ring".equals(type)) ring(ctx, d);
        else if ("end".equals(type)) missed(ctx, d);
        else stop(ctx, id);
    }

    static String val(Map<String, String> d, String k) {
        String v = d.get(k);
        return v == null ? "" : v;
    }

    static String ringText(Context ctx, Map<String, String> d) {
        boolean video = "1".equals(d.get("video"));
        String task = val(d, "task");
        String head = video ? tr(ctx, "مكالمة فيديو — Ninety", "Video call — Ninety") : tr(ctx, "مكالمة صوت — Ninety", "Voice call — Ninety");
        if (task.isEmpty()) return head;
        String imp = "1".equals(d.get("important")) ? tr(ctx, "هام — ", "Important — ") : "";
        return imp + tr(ctx, "بخصوص: ", "About: ") + task;
    }

    @SuppressLint("MissingPermission")
    static void ring(Context ctx, Map<String, String> d) {
        String id = val(d, "callId");
        long exp = 0;
        try { exp = Long.parseLong(val(d, "exp")); } catch (Exception ignored) { }
        if (exp > 0 && System.currentTimeMillis() > exp) return;
        if (handled(ctx, id)) return;
        if (appInFront(ctx)) return;   /* the app is open on the screen — its own call screen rings */
        if (showing(ctx, nid(id))) return;   /* already ringing (the caller's page rings again every few seconds) */
        channels(ctx);
        String caller = val(d, "caller");
        if (caller.isEmpty()) caller = val(d, "title");
        if (caller.isEmpty()) caller = "Ninety";
        String text = ringText(ctx, d);
        String t = val(d, "t");
        boolean video = "1".equals(d.get("video"));
        int n = nid(id);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;

        Intent full = new Intent(ctx, IncomingCallActivity.class);
        full.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_USER_ACTION);
        full.putExtra("callId", id);
        full.putExtra("caller", caller);
        full.putExtra("text", text);
        full.putExtra("video", video);
        full.putExtra("t", t);
        PendingIntent fullPI = PendingIntent.getActivity(ctx, n, full, flags);

        Intent dec = new Intent(ctx, CallActionReceiver.class);
        dec.setAction(ACTION_DECLINE);
        dec.putExtra("callId", id);
        dec.putExtra("t", t);
        PendingIntent decPI = PendingIntent.getBroadcast(ctx, n + 1, dec, flags);

        PendingIntent ansPI = PendingIntent.getActivity(ctx, n + 2, answerIntent(ctx, id), flags);

        Person who = new Person.Builder().setName(caller).setImportant(true).build();
        NotificationCompat.Builder b = new NotificationCompat.Builder(ctx, CH_RING)
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setContentTitle(caller)
                .setContentText(text)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setTimeoutAfter(RING_MS)
                .setContentIntent(fullPI)
                .setFullScreenIntent(fullPI, true)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE), Notification.STREAM_DEFAULT)
                .setVibrate(new long[]{0, 1000, 800, 1000, 800})
                .setStyle(NotificationCompat.CallStyle.forIncomingCall(who, decPI, ansPI).setIsVideo(video));
        Notification nf = b.build();
        nf.flags |= Notification.FLAG_INSISTENT;
        try {
            NotificationManagerCompat.from(ctx).notify(n, nf);
        } catch (Exception e) {
            /* no notification permission — nothing to show */
        }
    }

    /** the launch intent of the app that opens straight on the call */
    static Intent answerIntent(Context ctx, String id) {
        Intent i = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (i == null) i = new Intent();
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        i.putExtra(EXTRA_ACTION, "answer");
        i.putExtra(EXTRA_CALL_ID, id);
        return i;
    }

    public static void stop(Context ctx, String id) {
        if (id == null) return;
        markHandled(ctx, id);
        try { NotificationManagerCompat.from(ctx).cancel(nid(id)); } catch (Exception ignored) { }
        IncomingCallActivity.finishIf(id);
    }

    @SuppressLint("MissingPermission")
    static void missed(Context ctx, Map<String, String> d) {
        String id = val(d, "callId");
        stop(ctx, id);
        channels(ctx);
        String caller = val(d, "caller");
        String title = val(d, "title");
        String body = val(d, "body");
        if (title.isEmpty()) title = tr(ctx, "مكالمة فايتة", "Missed call") + (caller.isEmpty() ? "" : " — " + caller);
        if (body.isEmpty()) body = ringText(ctx, d);
        String url = val(d, "url");
        if (url.isEmpty()) url = "/#/calls";
        Intent open = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (open == null) open = new Intent();
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        open.putExtra(EXTRA_ACTION, "open");
        open.putExtra(EXTRA_URL, url);
        int n = nid(id) + 3;
        PendingIntent pi = PendingIntent.getActivity(ctx, n, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        NotificationCompat.Builder b = new NotificationCompat.Builder(ctx, CH_MISSED)
                .setSmallIcon(android.R.drawable.sym_call_missed)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
                .setAutoCancel(true)
                .setContentIntent(pi);
        try {
            NotificationManagerCompat.from(ctx).notify(n, b.build());
        } catch (Exception ignored) { }
    }

    static boolean showing(Context ctx, int n) {
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return false;
            for (StatusBarNotification s : nm.getActiveNotifications()) if (s.getId() == n) return true;
        } catch (Exception ignored) { }
        return false;
    }

    static boolean appInFront(Context ctx) {
        try {
            ActivityManager.RunningAppProcessInfo i = new ActivityManager.RunningAppProcessInfo();
            ActivityManager.getMyMemoryState(i);
            if (i.importance != ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) return false;
            PowerManager pm = (PowerManager) ctx.getSystemService(Context.POWER_SERVICE);
            if (pm != null && !pm.isInteractive()) return false;
            KeyguardManager km = (KeyguardManager) ctx.getSystemService(Context.KEYGUARD_SERVICE);
            return km == null || !km.isKeyguardLocked();
        } catch (Exception e) {
            return false;
        }
    }

    /* a call that was answered / declined / ended here never rings again (a late duplicate message) */
    static void markHandled(Context ctx, String id) {
        try {
            SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            JSONObject o = new JSONObject(sp.getString("handled", "{}"));
            long now = System.currentTimeMillis();
            JSONObject keep = new JSONObject();
            java.util.Iterator<String> it = o.keys();
            while (it.hasNext()) {
                String k = it.next();
                long at = o.optLong(k, 0);
                if (now - at < 120000L) keep.put(k, at);
            }
            keep.put(id, now);
            sp.edit().putString("handled", keep.toString()).apply();
        } catch (Exception ignored) { }
    }

    static boolean handled(Context ctx, String id) {
        try {
            JSONObject o = new JSONObject(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("handled", "{}"));
            return System.currentTimeMillis() - o.optLong(id, 0) < 120000L;
        } catch (Exception e) {
            return false;
        }
    }

    /* ---------- what was pressed while the page was not there ---------- */
    static void setPending(Context ctx, String action, String callId, String url) {
        try {
            JSONObject o = new JSONObject();
            o.put("action", action);
            o.put("callId", callId == null ? "" : callId);
            o.put("url", url == null ? "" : url);
            o.put("at", System.currentTimeMillis());
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("pending", o.toString()).apply();
        } catch (Exception ignored) { }
    }

    static JSObject takePending(Context ctx) {
        JSObject r = new JSObject();
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String s = sp.getString("pending", null);
        if (s == null) return r;
        sp.edit().remove("pending").apply();
        try {
            JSONObject o = new JSONObject(s);
            if (System.currentTimeMillis() - o.optLong("at", 0) > 120000L) return r;
            r.put("action", o.optString("action", ""));
            r.put("callId", o.optString("callId", ""));
            r.put("url", o.optString("url", ""));
        } catch (Exception ignored) { }
        return r;
    }

    /** «Decline» on the call screen: close it and tell the server (no session needed — the token came with the ring) */
    static void decline(Context ctx, String id, String t, BroadcastReceiver.PendingResult pr) {
        stop(ctx, id);
        new Thread(() -> {
            HttpURLConnection con = null;
            try {
                if (id != null && t != null && !t.isEmpty()) {
                    JSONObject o = new JSONObject();
                    o.put("action", "call-decline");
                    o.put("id", id);
                    o.put("t", t);
                    con = (HttpURLConnection) new URL(API).openConnection();
                    con.setRequestMethod("POST");
                    con.setConnectTimeout(8000);
                    con.setReadTimeout(8000);
                    con.setDoOutput(true);
                    con.setRequestProperty("content-type", "application/json");
                    try (OutputStream os = con.getOutputStream()) {
                        os.write(o.toString().getBytes(StandardCharsets.UTF_8));
                    }
                    con.getResponseCode();
                }
            } catch (Exception ignored) {
            } finally {
                if (con != null) con.disconnect();
                if (pr != null) pr.finish();
            }
        }).start();
    }
}
