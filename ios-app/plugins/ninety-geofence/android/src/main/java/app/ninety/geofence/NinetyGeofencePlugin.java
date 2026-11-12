package app.ninety.geofence;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

/**
 * Ninety — native geofence (v8.14, brief claude/geofence-brief.md). JS: Capacitor.Plugins.NinetyGeofence
 *   .status() → { location, background, regions }
 *   .request() → asks «location» then (Android 10+) «all the time»; resolves with status()
 *   .setup({ url, token, regions: [{ id, lat, lng, radius }] }) → stores them and registers the circles with Android
 *   .clear()
 * Android wakes GeofenceReceiver on enter / exit even when the app is closed; it posts the event to the server (GeoStore.send).
 */
@CapacitorPlugin(
        name = "NinetyGeofence",
        permissions = {
                @Permission(alias = "location", strings = { Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION }),
                @Permission(alias = "background", strings = { Manifest.permission.ACCESS_BACKGROUND_LOCATION })
        }
)
public class NinetyGeofencePlugin extends Plugin {

    private JSObject st() {
        JSObject o = new JSObject();
        o.put("location", GeoStore.hasLocation(getContext()));
        o.put("background", GeoStore.hasBackground(getContext()));
        o.put("regions", GeoStore.prefs(getContext()).getString("regions", "[]"));
        o.put("platform", "android");
        return o;
    }

    @PluginMethod
    public void status(PluginCall call) { call.resolve(st()); }

    @PluginMethod
    public void request(PluginCall call) {
        if (!GeoStore.hasLocation(getContext())) { requestPermissionForAlias("location", call, "afterLocation"); return; }
        if (!GeoStore.hasBackground(getContext()) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { requestPermissionForAlias("background", call, "afterBackground"); return; }
        call.resolve(st());
    }

    @PermissionCallback
    private void afterLocation(PluginCall call) {
        if (getPermissionState("location") == PermissionState.GRANTED && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !GeoStore.hasBackground(getContext())) {
            requestPermissionForAlias("background", call, "afterBackground");
            return;
        }
        GeoStore.register(getContext());
        call.resolve(st());
    }

    @PermissionCallback
    private void afterBackground(PluginCall call) {
        GeoStore.register(getContext());
        call.resolve(st());
    }

    @PluginMethod
    public void setup(PluginCall call) {
        String url = call.getString("url"), token = call.getString("token");
        if (url == null || token == null) { call.reject("url / token missing"); return; }
        String regions = call.getArray("regions") != null ? call.getArray("regions").toString() : "[]";
        GeoStore.save(getContext(), url, token, regions);
        int n = GeoStore.register(getContext());
        JSObject o = st(); o.put("registered", n);
        call.resolve(o);
    }

    /* v11.24 — the route of a trip the driver started, recorded by the phone itself (TripTrackService). */
    @PluginMethod
    public void tripStart(PluginCall call) {
        String url = call.getString("url"), token = call.getString("token"), tripId = call.getString("tripId");
        if (url == null || token == null || tripId == null) { call.reject("url / token / tripId missing"); return; }
        Context c = getContext();
        if (!TripTrackService.hasLocation(c)) { call.reject("no-location"); return; }
        android.content.SharedPreferences p = TripTrackService.prefs(c);
        boolean same = TripTrackService.running && tripId.equals(p.getString("tripId", null));
        p.edit().putString("url", url).putString("token", token).putString("tripId", tripId)
                .putLong("since", same ? p.getLong("since", System.currentTimeMillis()) : System.currentTimeMillis()).apply();
        try {
            ContextCompat.startForegroundService(c, new Intent(c, TripTrackService.class));
        } catch (Exception e) { call.reject("start: " + e.getMessage()); return; }
        JSObject o = new JSObject(); o.put("running", true); o.put("tripId", tripId); call.resolve(o);
    }

    @PluginMethod
    public void tripStop(PluginCall call) {
        Context c = getContext();
        if (TripTrackService.running) {
            try {
                Intent i = new Intent(c, TripTrackService.class); i.setAction(TripTrackService.ACTION_STOP);
                c.startService(i);
            } catch (Exception e) {
                try { c.stopService(new Intent(c, TripTrackService.class)); } catch (Exception ignored) { }
                TripTrackService.prefs(c).edit().remove("tripId").remove("since").apply();
            }
        } else {
            TripTrackService.prefs(c).edit().remove("tripId").remove("since").apply();
        }
        JSObject o = new JSObject(); o.put("running", false); call.resolve(o);
    }

    @PluginMethod
    public void tripStatus(PluginCall call) {
        android.content.SharedPreferences p = TripTrackService.prefs(getContext());
        JSObject o = new JSObject(); o.put("running", TripTrackService.running); o.put("tripId", p.getString("tripId", null));
        int n = 0; try { n = new org.json.JSONArray(p.getString("pending", "[]")).length(); } catch (Exception ignored) { }
        o.put("pending", n); o.put("platform", "android"); call.resolve(o);
    }

    @PluginMethod
    public void clear(PluginCall call) {
        GeoStore.clear(getContext());
        call.resolve(st());
    }
}
