package app.ninety.geofence;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

import java.util.List;

/** Ninety — the phone woke us: the person entered / left a watched place. Tell the server (works with the app closed). */
public class GeofenceReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        GeofencingEvent ev = GeofencingEvent.fromIntent(intent);
        if (ev == null || ev.hasError()) return;
        int t = ev.getGeofenceTransition();
        if (t != Geofence.GEOFENCE_TRANSITION_ENTER && t != Geofence.GEOFENCE_TRANSITION_EXIT) return;
        final String kind = t == Geofence.GEOFENCE_TRANSITION_ENTER ? "enter" : "exit";
        final List<Geofence> list = ev.getTriggeringGeofences();
        if (list == null || list.isEmpty()) return;
        final Context app = context.getApplicationContext();
        final PendingResult pr = goAsync();
        new Thread(() -> {
            try {
                for (Geofence g : list) GeoStore.send(app, kind, g.getRequestId());
            } finally {
                pr.finish();
            }
        }).start();
    }
}
