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

/** The full-screen incoming call (also over the lock screen): caller, what it is about, «Decline» / «Answer». */
public class IncomingCallActivity extends Activity {
    private static WeakReference<IncomingCallActivity> current = new WeakReference<>(null);
    private String callId = "";
    private String token = "";
    private final Handler h = new Handler(Looper.getMainLooper());

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
        setContentView(root);

        h.removeCallbacksAndMessages(null);
        h.postDelayed(this::finish, CallUI.RING_MS);
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
        Runnable open = () -> {
            try { startActivity(CallUI.answerIntent(app, id)); } catch (Exception ignored) { }
            CallUI.stop(app, id);
            finish();
        };
        KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && km != null && km.isKeyguardLocked()) {
            km.requestDismissKeyguard(this, new KeyguardManager.KeyguardDismissCallback() {
                @Override
                public void onDismissSucceeded() { open.run(); }

                @Override
                public void onDismissCancelled() { }

                @Override
                public void onDismissError() { open.run(); }
            });
        } else {
            open.run();
        }
    }

    @Override
    protected void onDestroy() {
        h.removeCallbacksAndMessages(null);
        if (current.get() == this) current = new WeakReference<>(null);
        super.onDestroy();
    }
}
