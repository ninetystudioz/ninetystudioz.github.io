package app.ninety.calls;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.Chronometer;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.lang.ref.WeakReference;

/**
 * v12: the call screen of a call this phone answered by itself (NativeCall) — also over the lock screen:
 * who · «connecting…» then the timer · mute · speaker · hang up. Leaving it (home / back) keeps the call; the «call in progress»
 * notification comes back here.
 */
public class InCallActivity extends Activity {
    private static WeakReference<InCallActivity> current = new WeakReference<>(null);
    private final Handler h = new Handler(Looper.getMainLooper());
    private String callId = "";
    private TextView status;
    private Chronometer timer;
    private Button mute, spk;
    private boolean ticking = false;
    private android.os.PowerManager.WakeLock prox;   /* the screen goes dark against the ear (not on the loudspeaker) */

    static Intent intent(Context c) {
        Intent i = new Intent(c, InCallActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NO_USER_ACTION);
        return i;
    }

    static void open(Context c) {
        try { c.startActivity(intent(c)); } catch (Exception ignored) { }
    }

    static void refresh() {
        InCallActivity a = current.get();
        if (a != null) a.runOnUiThread(a::paint);
    }

    static void close(String id) {
        InCallActivity a = current.get();
        if (a != null && (id == null || id.equals(a.callId))) a.runOnUiThread(a::finish);
    }

    private int dp(float v) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics());
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        }
        getWindow().setStatusBarColor(Color.parseColor("#111214"));
        getWindow().setNavigationBarColor(Color.parseColor("#111214"));
        setVolumeControlStream(android.media.AudioManager.STREAM_VOICE_CALL);
        build();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        build();
    }

    private void build() {
        current = new WeakReference<>(this);
        if (!NativeCall.active()) { finish(); return; }
        callId = NativeCall.id();
        boolean ar = CallUI.arabic(this);
        String who = NativeCall.peerName();
        if (who == null || who.isEmpty()) who = "Ninety";

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setBackgroundColor(Color.parseColor("#111214"));
        root.setPadding(dp(24), dp(96), dp(24), dp(64));
        root.setLayoutDirection(ar ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);

        TextView badge = new TextView(this);
        badge.setText(who.substring(0, 1));
        badge.setTextColor(Color.WHITE);
        badge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 40);
        badge.setGravity(Gravity.CENTER);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(Color.parseColor("#3a3b3f"));
        badge.setBackground(circle);
        root.addView(badge, new LinearLayout.LayoutParams(dp(112), dp(112)));

        TextView name = new TextView(this);
        name.setText(who);
        name.setTextColor(Color.WHITE);
        name.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
        name.setTypeface(Typeface.DEFAULT_BOLD);
        name.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lpName = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpName.topMargin = dp(24);
        root.addView(name, lpName);

        status = new TextView(this);
        status.setTextColor(Color.parseColor("#c7c7cc"));
        status.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        status.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lpSub = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpSub.topMargin = dp(10);
        root.addView(status, lpSub);

        timer = new Chronometer(this);
        timer.setTextColor(Color.parseColor("#c7c7cc"));
        timer.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        timer.setGravity(Gravity.CENTER);
        timer.setVisibility(View.GONE);
        LinearLayout.LayoutParams lpT = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpT.topMargin = dp(10);
        root.addView(timer, lpT);

        View space = new View(this);
        root.addView(space, new LinearLayout.LayoutParams(1, 0, 1f));

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER);
        mute = roundButton("", "#3a3b3f");
        spk = roundButton("", "#3a3b3f");
        Button end = roundButton(ar ? "إنهاء" : "End", "#ff3b30");
        LinearLayout.LayoutParams lpb = new LinearLayout.LayoutParams(dp(84), dp(84));
        lpb.leftMargin = dp(14);
        lpb.rightMargin = dp(14);
        row.addView(mute, lpb);
        row.addView(end, new LinearLayout.LayoutParams(lpb));
        row.addView(spk, new LinearLayout.LayoutParams(lpb));
        root.addView(row, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        mute.setOnClickListener(v -> NativeCall.setMuted(!NativeCall.isMuted()));
        spk.setOnClickListener(v -> NativeCall.setSpeaker(!NativeCall.isSpeaker()));
        end.setOnClickListener(v -> {
            NativeCall.hangup(getApplicationContext());
            finish();
        });
        setContentView(root);
        ticking = false;
        paint();
    }

    private void paint() {
        if (!NativeCall.owns(callId)) { finish(); return; }
        boolean ar = CallUI.arabic(this);
        boolean on = NativeCall.isConnected();
        if (on) {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            status.setVisibility(View.GONE);
            timer.setVisibility(View.VISIBLE);
            if (!ticking) { ticking = true; timer.setBase(SystemClock.elapsedRealtime()); timer.start(); }
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            status.setVisibility(View.VISIBLE);
            status.setText(ar ? "جاري التوصيل…" : "Connecting…");
        }
        proximity(!NativeCall.isSpeaker());
        tint(mute, NativeCall.isMuted(), ar ? (NativeCall.isMuted() ? "مكتوم" : "كتم") : (NativeCall.isMuted() ? "Muted" : "Mute"));
        tint(spk, NativeCall.isSpeaker(), ar ? "سبيكر" : "Speaker");
    }

    @SuppressWarnings("deprecation")
    private void proximity(boolean on) {
        try {
            if (on) {
                if (prox == null) {
                    android.os.PowerManager pm = (android.os.PowerManager) getSystemService(Context.POWER_SERVICE);
                    if (pm == null || !pm.isWakeLockLevelSupported(android.os.PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return;
                    prox = pm.newWakeLock(android.os.PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "ninety:incall");
                    prox.setReferenceCounted(false);
                }
                if (!prox.isHeld()) prox.acquire(4 * 60 * 60 * 1000L);
            } else if (prox != null && prox.isHeld()) {
                prox.release();
            }
        } catch (Exception ignored) { }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (NativeCall.owns(callId)) paint(); else finish();
    }

    private void tint(Button b, boolean on, String label) {
        b.setText(label);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(Color.parseColor(on ? "#f2f2f7" : "#3a3b3f"));
        b.setBackground(g);
        b.setTextColor(on ? Color.parseColor("#111214") : Color.WHITE);
    }

    private Button roundButton(String label, String color) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextColor(Color.WHITE);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(Color.parseColor(color));
        b.setBackground(g);
        b.setStateListAnimator(null);
        return b;
    }

    @Override
    protected void onDestroy() {
        proximity(false);
        h.removeCallbacksAndMessages(null);
        if (current.get() == this) current = new WeakReference<>(null);
        super.onDestroy();
    }
}
