package app.ninety.geofence;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Ninety — the phone restarted (or the app updated): geofences are dropped by Android then, register them again. */
public class GeoBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        try { GeoStore.register(context.getApplicationContext()); } catch (Exception ignored) { }
    }
}
