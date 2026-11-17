package app.ninety.calls;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/**
 * v12 (Mahmoud 17 Nov «الحل الكامل على طول»): the call screen answers by itself — it does not wait for the web page.
 * «Answer» → Edge «callx» (the per-call token of the ring push) → the call is active on the server and this phone joins the
 * LiveKit room here (NinetyLK) with a «call in progress» service and its own call screen (InCallActivity). The caller's page
 * joins the same room when it sees the answer. When the caller is on the old engine, there is no microphone permission yet, or
 * the network call fails → the old way (the app opens and the page answers), nothing lost.
 * The call ends: the red button here · the other side left the room · the server says the call is over.
 */
public final class NativeCall {
    static final String API = "https://erhcnkjyaumdoixkksbz.supabase.co/functions/v1/callx";
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    interface Result {
        /** main thread. ok = this phone is in the call; otherwise mode says why («page» = answer through the page) */
        void done(boolean ok, String mode);
    }

    private static volatile String callId = "";
    private static volatile String token = "";
    private static volatile String pcId = "";
    private static volatile String peer = "";
    private static volatile long since = 0L;
    private static volatile boolean connected = false;
    private static volatile boolean answering = false;
    private static volatile String answerId = "";   /* the call being answered right now (the server has not replied yet) */
    private static int gen = 0;                      /* main thread: one number per native call — old timers do nothing */
    private static volatile boolean muted = false;
    private static volatile boolean speaker = false;

    private NativeCall() { }

    /** once (the plugin loads, or the first native answer): the native call hears its room */
    static void bind(final Context app) {
        NinetyLK.setNativeSink(o -> MAIN.post(() -> onRoomEvent(app, o)));
    }

    static boolean owns(String id) { return id != null && !id.isEmpty() && id.equals(callId); }
    /** this phone is answering / has answered this call itself — a «stop» push for it is not for this phone */
    static boolean busyWith(String id) { return owns(id) || (id != null && !id.isEmpty() && id.equals(answerId)); }
    static boolean active() { return !callId.isEmpty(); }
    static String id() { return callId; }
    static String peerName() { return peer; }
    static long startedAt() { return since; }
    static boolean isConnected() { return connected; }
    static boolean isMuted() { return muted; }
    static boolean isSpeaker() { return speaker; }

    static JSObject state() {
        JSObject o = new JSObject();
        o.put("callId", callId);
        o.put("active", active());
        o.put("pcId", pcId);
        o.put("peer", peer);
        o.put("since", since);
        o.put("connected", connected);
        o.put("muted", muted);
        o.put("speaker", speaker);
        return o;
    }

    static boolean micGranted(Context c) {
        try { return ContextCompat.checkSelfPermission(c, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED; } catch (Exception e) { return false; }
    }

    /** blocking — never on the main thread */
    private static JSONObject post(JSONObject o, int timeoutMs) throws Exception {
        HttpURLConnection con = null;
        try {
            con = (HttpURLConnection) new URL(API).openConnection();
            con.setRequestMethod("POST");
            con.setConnectTimeout(timeoutMs);
            con.setReadTimeout(timeoutMs);
            con.setDoOutput(true);
            con.setRequestProperty("content-type", "application/json");
            try (OutputStream os = con.getOutputStream()) { os.write(o.toString().getBytes(StandardCharsets.UTF_8)); }
            int code = con.getResponseCode();
            InputStream in = code >= 400 ? con.getErrorStream() : con.getInputStream();
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            if (in != null) { byte[] buf = new byte[4096]; int n; while ((n = in.read(buf)) > 0) bo.write(buf, 0, n); in.close(); }
            String s = bo.toString("UTF-8");
            JSONObject r = s.isEmpty() ? new JSONObject() : new JSONObject(s);
            r.put("_http", code);
            return r;
        } finally {
            if (con != null) con.disconnect();
        }
    }

    /** fire and forget: «diag» / «end» / «rang» */
    static void tell(final String action, final String id, final String t, final String step, final String err, final JSONObject extra) {
        if (id == null || id.isEmpty() || t == null || t.isEmpty()) return;
        new Thread(() -> {
            try {
                JSONObject o = new JSONObject();
                o.put("action", action);
                o.put("id", id);
                o.put("t", t);
                o.put("plat", "android");
                if (step != null) { o.put("step", step); o.put("why", step); }
                if (err != null) o.put("err", err);
                if (extra != null) o.put("extra", extra);
                post(o, 8000);
            } catch (Exception ignored) { }
        }).start();
    }

    /** «Answer» on the call screen. Calls back on the main thread, once. */
    static void answer(final Context app, final String id, final String t, final String caller, final Result done) {
        if (id == null || id.isEmpty() || t == null || t.isEmpty()) { done.done(false, "page"); return; }
        if (owns(id)) { done.done(true, "native"); return; }
        if (active() || answering || NinetyLK.count() > 0) { done.done(false, "page"); return; }   /* another call is on — the page decides */
        if (!micGranted(app)) { done.done(false, "page"); return; }                                 /* the page asks for the microphone */
        answering = true;
        answerId = id;
        final long t0 = System.currentTimeMillis();
        new Thread(() -> {
            JSONObject r = null;
            String fail = null;
            try {
                JSONObject o = new JSONObject();
                o.put("action", "answer");
                o.put("id", id);
                o.put("t", t);
                o.put("plat", "android");
                r = post(o, 9000);
            } catch (Exception e) {
                fail = "net";
            }
            final JSONObject res = r;
            final String f = fail;
            MAIN.post(() -> {
                if (f != null || res == null || !res.optBoolean("ok", false)) {
                    answering = false;
                    answerId = "";
                    String mode = f != null ? "page" : res.optString("mode", "");
                    if (mode.isEmpty()) mode = "gone:" + res.optString("state", String.valueOf(res.optInt("_http", 0)));
                    done.done(false, mode);
                    return;
                }
                final String url = res.optString("url", "");
                final String tok = res.optString("token", "");
                final String name = res.optString("name", "");
                callId = id;
                answerId = "";
                final int g = ++gen;
                token = t;
                pcId = "nat" + id;
                peer = caller != null && !caller.isEmpty() ? caller : name;
                since = System.currentTimeMillis();
                connected = false;
                muted = false;
                speaker = false;
                bind(app);
                CallService.start(app);
                final String pc = pcId;
                NinetyLK.join(app, pc, url, tok, null, false, err -> {
                    answering = false;
                    try {
                        JSONObject x = new JSONObject();
                        x.put("ms", System.currentTimeMillis() - t0);
                        tell("diag", id, t, err == null ? "joined" : "join-err", err, x);
                    } catch (Exception ignored) { }
                    if (err != null) {
                        if (owns(id)) finish(app, "join-err", true);
                        done.done(false, "gone:join");
                    } else {
                        /* nobody else in the room after 30 s (the caller's page never came) → do not hold the line for ever */
                        MAIN.postDelayed(() -> { if (g == gen && owns(id) && !connected) finish(app, "no-peer", true); }, 30000);
                        done.done(true, "native");
                    }
                });
            });
        }).start();
    }

    /** room events of the native call (NinetyLK.nativeSink, main thread) */
    static void onRoomEvent(Context app, JSObject e) {
        if (e == null || !active() || !pcId.equals(e.optString("pcId", ""))) return;
        String kind = e.optString("kind", "");
        int peers = e.optInt("peers", -1);
        if ("track".equals(kind) || (("peer".equals(kind) || "joined".equals(kind)) && peers > 0)) {
            if (!connected) { connected = true; InCallActivity.refresh(); }
            return;
        }
        if ("peer-left".equals(kind) && peers == 0) {
            /* the other side left the room: a short wait first — a phone that changes network leaves and comes back */
            final String id = callId, pc = pcId;
            final int g = gen;
            MAIN.postDelayed(() -> {
                if (g != gen || !owns(id)) return;
                int now = -1;
                try { now = NinetyLK.state(pc).optInt("peers", -1); } catch (Exception ignored) { }
                if (now <= 0) finish(app, "remote", true);
            }, 6000);
            return;
        }
        if ("state".equals(kind) && "disconnected".equals(e.optString("state", ""))) { finish(app, "disconnected", true); return; }
        if ("mic".equals(kind) && e.has("error")) tell("diag", callId, token, "mic-err", e.optString("error", ""), null);
    }

    static void setMuted(boolean on) { muted = on; NinetyLK.setMuted(on); InCallActivity.refresh(); }
    static void setSpeaker(boolean on) { speaker = on; NinetyLK.setSpeaker(on); InCallActivity.refresh(); }

    /** the red button */
    static void hangup(Context app) { finish(app, "user", true); }

    /** the server said this call is over (a «stop» / «end» push after the answer) */
    static void remoteEnded(Context app, String id) { if (owns(id)) finish(app, "push", false); }

    /** main thread */
    static void finish(final Context app, final String why, final boolean tellServer) {
        final String id = callId, t = token, pc = pcId;
        if (id.isEmpty()) return;
        final long dur = System.currentTimeMillis() - since;
        final boolean was = connected;
        callId = "";
        token = "";
        pcId = "";
        connected = false;
        answering = false;
        answerId = "";
        gen++;
        Runnable r = () -> {
            try { NinetyLK.leave(pc); } catch (Exception ignored) { }
            if (NinetyLK.count() == 0) CallService.stop(app);
            InCallActivity.close(id);
            if (tellServer) {
                try {
                    JSONObject x = new JSONObject();
                    x.put("durMs", dur);
                    x.put("connected", was);
                    tell("end", id, t, why, null, x);
                } catch (Exception ignored) { }
            }
        };
        if (Looper.myLooper() == Looper.getMainLooper()) r.run(); else MAIN.post(r);
    }
}
