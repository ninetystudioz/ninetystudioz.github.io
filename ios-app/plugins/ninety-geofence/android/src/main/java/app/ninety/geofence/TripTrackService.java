package app.ninety.geofence;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;

import androidx.core.app.NotificationCompat;
import androidx.core.app.ServiceCompat;
import androidx.core.content.ContextCompat;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Ninety v11.24 — the route of a trip the driver started, recorded by the phone itself (not the web view), with a visible
 * notification while it runs. A point every ~5 s, sent to the factory server (Edge geo-ping, action «trip») every 30 s.
 * It stops when the app says so, when the server answers that the trip is over, or after 14 hours.
 */
public class TripTrackService extends Service {
    static final String PREFS = "nf_trip";
    static final String ACTION_STOP = "app.ninety.geofence.TRIP_STOP";
    static final String CHANNEL = "ninety_trip";
    static final int NOTE_ID = 47112;
    static final int MAX_PENDING = 900;
    static final long FLUSH_MS = 30_000L;
    static final long MAX_RUN_MS = 14L * 3600_000L;
    static volatile boolean running = false;

    private FusedLocationProviderClient fused;
    private LocationCallback callback;
    private HandlerThread thread;
    private Handler handler;
    private final Object lock = new Object();
    private JSONArray pending = new JSONArray();
    private boolean flushing = false;

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE); }

    static boolean hasLocation(Context c) {
        return ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                || ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private static String iso(long ms) {
        SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
        f.setTimeZone(TimeZone.getTimeZone("UTC"));
        return f.format(new Date(ms));
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        thread = new HandlerThread("nf-trip");
        thread.start();
        handler = new Handler(thread.getLooper());
        try { pending = new JSONArray(prefs(this).getString("pending", "[]")); } catch (Exception e) { pending = new JSONArray(); }
    }

    private Notification note() {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm != null && nm.getNotificationChannel(CHANNEL) == null) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "Trip route", NotificationManager.IMPORTANCE_LOW);
            ch.setShowBadge(false);
            nm.createNotificationChannel(ch);
        }
        PendingIntent open = null;
        try {
            Intent li = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (li != null) {
                int fl = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) fl |= PendingIntent.FLAG_IMMUTABLE;
                open = PendingIntent.getActivity(this, 0, li, fl);
            }
        } catch (Exception ignored) { }
        NotificationCompat.Builder b = new NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("Ninety")
                .setContentText("المشوار شغّال — بنسجّل خط السير")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE);
        if (open != null) b.setContentIntent(open);
        return b.build();
    }

    private boolean goForeground() {
        try {
            int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ? ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION : 0;
            ServiceCompat.startForeground(this, NOTE_ID, note(), type);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        boolean fg = goForeground();
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            finish(true);
            return START_NOT_STICKY;
        }
        SharedPreferences p = prefs(this);
        long since = p.getLong("since", 0L);
        if (!fg || p.getString("tripId", null) == null || p.getString("url", null) == null || p.getString("token", null) == null
                || !hasLocation(this) || (since > 0 && System.currentTimeMillis() - since > MAX_RUN_MS)) {
            finish(false);
            return START_NOT_STICKY;
        }
        if (!running) startUpdates();
        /* not sticky: a restart by the system from the background may not start a location service on newer Android — the app restarts it when opened */
        return START_NOT_STICKY;
    }

    @SuppressLint("MissingPermission")
    private void startUpdates() {
        try {
            fused = LocationServices.getFusedLocationProviderClient(this);
            LocationRequest req = new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000L)
                    .setMinUpdateIntervalMillis(3000L)
                    .setMinUpdateDistanceMeters(0f)
                    .setWaitForAccurateLocation(false)
                    .build();
            callback = new LocationCallback() {
                @Override
                public void onLocationResult(LocationResult r) {
                    if (r == null) return;
                    for (Location l : r.getLocations()) add(l);
                }
            };
            fused.requestLocationUpdates(req, callback, thread.getLooper());
            running = true;
            handler.postDelayed(tick, FLUSH_MS);
        } catch (Exception e) {
            finish(false);
        }
    }

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            SharedPreferences p = prefs(TripTrackService.this);
            long since = p.getLong("since", 0L);
            if (since > 0 && System.currentTimeMillis() - since > MAX_RUN_MS) { finish(true); return; }
            flush(false);
            if (running) handler.postDelayed(this, FLUSH_MS);
        }
    };

    private void add(Location l) {
        try {
            JSONObject o = new JSONObject();
            o.put("lat", Math.round(l.getLatitude() * 1e6) / 1e6);
            o.put("lng", Math.round(l.getLongitude() * 1e6) / 1e6);
            o.put("at", iso(l.getTime() > 0 ? l.getTime() : System.currentTimeMillis()));
            if (l.hasAccuracy()) o.put("acc", Math.round(l.getAccuracy()));
            if (l.hasSpeed()) o.put("kmh", Math.round(l.getSpeed() * 3.6));
            synchronized (lock) {
                pending.put(o);
                if (pending.length() > MAX_PENDING) {
                    JSONArray cut = new JSONArray();
                    for (int i = pending.length() - MAX_PENDING; i < pending.length(); i++) cut.put(pending.get(i));
                    pending = cut;
                }
                prefs(this).edit().putString("pending", pending.toString()).apply();
            }
        } catch (Exception ignored) { }
    }

    /** sends what is waiting; on «stop» from the server the service ends. Runs on the service thread. */
    private void flush(boolean last) {
        JSONArray batch;
        synchronized (lock) {
            if (flushing || pending.length() == 0) { if (last) prefs(this).edit().remove("pending").apply(); return; }
            flushing = true;
            batch = pending;
        }
        SharedPreferences p = prefs(this);
        String url = p.getString("url", null), token = p.getString("token", null), tripId = p.getString("tripId", null);
        boolean stop = false;
        HttpURLConnection con = null;
        try {
            if (url == null || token == null || tripId == null) return;
            JSONObject b = new JSONObject();
            b.put("action", "trip"); b.put("token", token); b.put("tripId", tripId); b.put("pts", batch); b.put("last", last);
            con = (HttpURLConnection) new URL(url).openConnection();
            con.setRequestMethod("POST"); con.setConnectTimeout(15000); con.setReadTimeout(20000); con.setDoOutput(true);
            con.setRequestProperty("content-type", "application/json");
            try (OutputStream os = con.getOutputStream()) { os.write(b.toString().getBytes(StandardCharsets.UTF_8)); }
            int code = con.getResponseCode();
            if (code == 200) {
                String body = "";
                try (InputStream is = con.getInputStream(); ByteArrayOutputStream bo = new ByteArrayOutputStream()) {
                    byte[] buf = new byte[4096]; int n;
                    while ((n = is.read(buf)) > 0) bo.write(buf, 0, n);
                    body = bo.toString("UTF-8");
                } catch (Exception ignored) { }
                synchronized (lock) {
                    JSONArray rest = new JSONArray();
                    for (int i = batch.length(); i < pending.length(); i++) rest.put(pending.get(i));
                    pending = rest;
                    p.edit().putString("pending", pending.toString()).apply();
                }
                try { stop = new JSONObject(body).optBoolean("stop", false); } catch (Exception ignored) { }
            } else if (code == 403) {
                stop = true;
            }
        } catch (Exception ignored) {
        } finally {
            if (con != null) con.disconnect();
            synchronized (lock) { flushing = false; }
        }
        if (stop && !last) finish(false);
    }

    private void finish(boolean sendLast) {
        final boolean wasRunning = running;
        running = false;
        try { if (fused != null && callback != null) fused.removeLocationUpdates(callback); } catch (Exception ignored) { }
        if (handler != null) handler.removeCallbacks(tick);
        Runnable end = () -> {
            if (sendLast && wasRunning) flush(true);
            prefs(this).edit().remove("tripId").remove("since").apply();
            try { ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE); } catch (Exception ignored) { }
            stopSelf();
        };
        if (handler != null) handler.post(end); else end.run();
    }

    @Override
    public void onDestroy() {
        running = false;
        try { if (fused != null && callback != null) fused.removeLocationUpdates(callback); } catch (Exception ignored) { }
        if (handler != null) handler.removeCallbacksAndMessages(null);
        if (thread != null) thread.quitSafely();
        super.onDestroy();
    }
}
