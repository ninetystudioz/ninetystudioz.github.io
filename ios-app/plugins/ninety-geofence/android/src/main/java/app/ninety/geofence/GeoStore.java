package app.ninety.geofence;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.core.content.ContextCompat;

import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/** Ninety — geofence storage + registration + the call to the server (shared by the plugin, the receiver and the boot receiver). */
public final class GeoStore {
    static final String PREFS = "nf_geofence";
    private GeoStore() {}

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE); }

    static void save(Context c, String url, String token, String regionsJson) {
        prefs(c).edit().putString("url", url).putString("token", token).putString("regions", regionsJson).apply();
    }

    static void clear(Context c) {
        prefs(c).edit().clear().apply();
        try { LocationServices.getGeofencingClient(c).removeGeofences(pending(c)); } catch (Exception ignored) { }
    }

    static PendingIntent pending(Context c) {
        Intent i = new Intent(c, GeofenceReceiver.class);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags |= PendingIntent.FLAG_MUTABLE;
        return PendingIntent.getBroadcast(c, 4711, i, flags);
    }

    static boolean hasLocation(Context c) {
        return ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    static boolean hasBackground(Context c) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return hasLocation(c);
        return ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    /** (re)register every stored region; returns how many were registered (0 when no permission / nothing stored). */
    @SuppressLint("MissingPermission")
    static int register(Context c) {
        try {
            String rj = prefs(c).getString("regions", null);
            if (rj == null || !hasLocation(c)) return 0;
            JSONArray arr = new JSONArray(rj);
            List<Geofence> list = new ArrayList<>();
            for (int k = 0; k < arr.length() && k < 90; k++) {
                JSONObject r = arr.getJSONObject(k);
                float rad = (float) Math.max(100, r.optDouble("radius", 200));
                list.add(new Geofence.Builder()
                        .setRequestId(r.optString("id", "factory"))
                        .setCircularRegion(r.getDouble("lat"), r.getDouble("lng"), rad)
                        .setExpirationDuration(Geofence.NEVER_EXPIRE)
                        .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER | Geofence.GEOFENCE_TRANSITION_EXIT)
                        .setNotificationResponsiveness(60000)
                        .build());
            }
            GeofencingClient gc = LocationServices.getGeofencingClient(c);
            gc.removeGeofences(pending(c));
            if (list.isEmpty()) return 0;
            GeofencingRequest req = new GeofencingRequest.Builder()
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                    .addGeofences(list).build();
            gc.addGeofences(req, pending(c));
            return list.size();
        } catch (Exception e) {
            return 0;
        }
    }

    /** POST {action:'event', token, ev, region} to the factory server (Edge geo-ping). Runs off the main thread. */
    static void send(Context c, String ev, String region) {
        String url = prefs(c).getString("url", null), token = prefs(c).getString("token", null);
        if (url == null || token == null) return;
        HttpURLConnection con = null;
        try {
            JSONObject b = new JSONObject();
            b.put("action", "event"); b.put("token", token); b.put("ev", ev); b.put("region", region); b.put("at", System.currentTimeMillis());
            con = (HttpURLConnection) new URL(url).openConnection();
            con.setRequestMethod("POST"); con.setConnectTimeout(15000); con.setReadTimeout(15000); con.setDoOutput(true);
            con.setRequestProperty("content-type", "application/json");
            try (OutputStream os = con.getOutputStream()) { os.write(b.toString().getBytes(StandardCharsets.UTF_8)); }
            con.getResponseCode();
        } catch (Exception ignored) {
        } finally {
            if (con != null) con.disconnect();
        }
    }
}
