package app.ninety.calls;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** «Decline» on the call notification — works with the app closed (tells the server with the per-call token). */
public class CallActionReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !CallUI.ACTION_DECLINE.equals(intent.getAction())) return;
        PendingResult pr = goAsync();
        CallUI.decline(context.getApplicationContext(), intent.getStringExtra("callId"), intent.getStringExtra("t"), pr);
    }
}
