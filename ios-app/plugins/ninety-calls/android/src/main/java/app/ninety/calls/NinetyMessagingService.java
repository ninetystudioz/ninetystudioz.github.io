package app.ninety.calls;

import com.capacitorjs.plugins.pushnotifications.MessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

/** FCM entry point: a call message (data «nfcall»=1) becomes the call screen; everything else goes on to Capacitor as before. */
public class NinetyMessagingService extends MessagingService {
    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        Map<String, String> d = remoteMessage.getData();
        if (d != null && "1".equals(d.get("nfcall"))) {
            CallUI.handle(getApplicationContext(), d);
            return;
        }
        super.onMessageReceived(remoteMessage);
    }
}
