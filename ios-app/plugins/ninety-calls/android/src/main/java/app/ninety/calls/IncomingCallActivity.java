package app.ninety.calls;

import android.app.Activity;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.lang.ref.WeakReference;

/** The full-screen incoming call (also over the lock screen): caller, what it is about, «Decline» / «Answer».
 *  v8.20: «Answer» opens the app straight over the lock screen (the app shows over it while the call lasts) — no PIN first;
 *  «Answer» on the notification comes here with answerNow and answers at once. */
public class IncomingCallActivity extends Activity {
    private static WeakReference<IncomingCallActivity> current = new WeakReference<>(null);
    private String callId = "";
    private String token = "";
    private final Handler h = new Handler(Looper.getMainLooper());
    private boolean answering = false;
    private TextView subText;
    private Button btnAnswer, btnDecline;

    static void finishIf(String id) {
        IncomingCallActivity a = current.get();
        if (a != null && id != null && id.equals(a.callId)) a.runOnUiThread(a::finish);
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
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().setStatusBarColor(Color.parseColor("#111214"));
        getWindow().setNavigationBarColor(Color.parseColor("#111214"));
        show(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        show(intent);
    }

    private void show(Intent in) {
        current = new WeakReference<>(this);
        callId = in.getStringExtra("callId") == null ? "" : in.getStringExtra("callId");
        token = in.getStringExtra("t") == null ? "" : in.getStringExtra("t");
        String caller = in.getStringExtra("caller") == null ? "Ninety" : in.getStringExtra("caller");
        String text = in.getStringExtra("text") == null ? "" : in.getStringExtra("text");
        boolean ar = CallUI.arabic(this);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setBackgroundColor(Color.parseColor("#111214"));
        root.setPadding(dp(24), dp(96), dp(24), dp(64));
        root.setLayoutDirection(ar ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);

        TextView badge = new TextView(this);
        badge.setText(caller.isEmpty() ? "N" : caller.substring(0, 1));
        badge.setTextColor(Color.WHITE);
        badge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 40);
        badge.setGravity(Gravity.CENTER);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(Color.parseColor("#3a3b3f"));
        badge.setBackground(circle);
        root.addView(badge, new LinearLayout.LayoutParams(dp(112), dp(112)));

        TextView name = new TextView(this);
        name.setText(caller);
        name.setTextColor(Color.WHITE);
        name.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
        name.setTypeface(Typeface.DEFAULT_BOLD);
        name.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lpName = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpName.topMargin = dp(24);
        root.addView(name, lpName);

        TextView sub = new TextView(this);
        sub.setText(text);
        sub.setTextColor(Color.parseColor("#c7c7cc"));
        sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        sub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lpSub = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lpSub.topMargin = dp(10);
        root.addView(sub, lpSub);
        subText = sub;

        View space = new View(this);
        root.addView(space, new LinearLayout.LayoutParams(1, 0, 1f));

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER);
        Button decline = roundButton(ar ? "رفض" : "Decline", "#ff3b30");
        Button answer = roundButton(ar ? "رد" : "Answer", "#34c759");
        LinearLayout.LayoutParams lpb = new LinearLayout.LayoutParams(dp(84), dp(84));
        lpb.leftMargin = dp(36);
        lpb.rightMargin = dp(36);
        row.addView(decline, lpb);
        row.addView(answer, new LinearLayout.LayoutParams(lpb));
        root.addView(row, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        decline.setOnClickListener(v -> {
            CallUI.decline(getApplicationContext(), callId, token, null);
            finish();
        });
        answer.setOnClickListener(v -> answer());
        btnAnswer = answer;
        btnDecline = decline;
        answering = false;
        setContentView(root);

        h.removeCallbacksAndMessages(null);
        h.postDelayed(this::finish, CallUI.RING_MS);
        if (in.getBooleanExtra("answerNow", false)) {
            in.removeExtra("answerNow");
            h.post(this::answer);
        }
    }

    private Button roundButton(String label, String color) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextColor(Color.WHITE);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(Color.parseColor(color));
        b.setBackground(g);
        b.setStateListAnimator(null);
        return b;
    }

    private void answer() {
        final String id = callId;
        final Context app = getApplicationContext();
        if (answering) return;
        answering = true;
        h.removeCallbacksAndMessages(null);
        CallUI.silence(app, id);   /* the ringtone stops at the tap */
        try {
            if (subText != null) subText.setText(CallUI.tr(this, "جاري الرد…", "Answering…"));
            if (btnAnswer != null) { btnAnswer.setEnabled(false); btnAnswer.setAlpha(0.45f); }
            if (btnDecline != null) { btnDecline.setEnabled(false); btnDecline.setAlpha(0.45f); }
        } catch (Exception ignored) { }
        /* v12: the call screen answers by itself (NativeCall → Edge «callx» → the LiveKit room) — no web page on the way.
           «page» = the caller is on the old engine / no microphone permission yet / no network answer → the old way below. */
        final String who = getIntent() == null || getIntent().getStringExtra("caller") == null ? "" : getIntent().getStringExtra("caller");
        NativeCall.answer(app, id, token, who, (ok, mode) -> {
            answering = false;
            if (ok) {
                /* from this screen while it is still on top (Android does not let the background open a screen) */
                try { startActivity(InCallActivity.intent(this)); } catch (Exception e) { InCallActivity.open(app); }
                CallUI.stop(app, id);
                finish();
                return;
            }
            if (mode != null && mode.startsWith("gone")) {   /* the call is over (answered elsewhere / the caller hung up) */
                CallUI.stop(app, id);
                finish();
                return;
            }
            /* v8.20: no keyguard dismissal (a PIN prompt could block or cancel the answer) — the app opens over the lock screen */
            try { startActivity(CallUI.answerIntent(app, id)); } catch (Exception ignored) { }
            CallUI.stop(app, id);
            finish();
        });
    }

    @Override
    protected void onDestroy() {
        h.removeCallbacksAndMessages(null);
        if (current.get() == this) current = new WeakReference<>(null);
        super.onDestroy();
    }
}
