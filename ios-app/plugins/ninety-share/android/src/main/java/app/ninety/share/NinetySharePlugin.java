package app.ninety.share;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Base64;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.ArrayList;

/**
 * Ninety — «Share» → Ninety on Android (v7.57). The app (MainActivity, intent filters added by scripts/configure-android.py)
 * receives images / PDFs; the web page takes them with take() and shows «Send to a task». A share while the app is open
 * fires the window event «nfshare». setContext / clear are iPhone-only (kept here as no-ops so the page can call them anywhere).
 */
@CapacitorPlugin(name = "NinetyShare")
public class NinetySharePlugin extends Plugin {
    private static final int MAX_FILES = 10;
    private static final int MAX_BYTES = 15 * 1024 * 1024;
    private JSArray pending = null;
    private String pendingText = null;

    @Override
    public void load() {
        try {
            Intent i = getActivity() != null ? getActivity().getIntent() : null;
            if (i != null) grab(i, false);
        } catch (Exception e) { /* nothing shared */ }
    }

    @Override
    protected void handleOnNewIntent(Intent intent) {
        super.handleOnNewIntent(intent);
        try { grab(intent, true); } catch (Exception e) { /* ignore */ }
    }

    private boolean grab(Intent intent, boolean notify) {
        String a = intent.getAction();
        if (!Intent.ACTION_SEND.equals(a) && !Intent.ACTION_SEND_MULTIPLE.equals(a)) return false;
        ArrayList<Uri> uris = new ArrayList<>();
        if (Intent.ACTION_SEND.equals(a)) {
            Uri u = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (u != null) uris.add(u);
        } else {
            ArrayList<Uri> l = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
            if (l != null) uris.addAll(l);
        }
        JSArray arr = new JSArray();
        ContentResolver cr = getContext().getContentResolver();
        for (Uri u : uris) {
            if (arr.length() >= MAX_FILES) break;
            try {
                String mime = cr.getType(u);
                byte[] b = readAll(cr.openInputStream(u));
                if (b == null) continue;
                JSObject o = new JSObject();
                o.put("name", nameOf(cr, u));
                o.put("mime", mime == null ? "application/octet-stream" : mime);
                o.put("data", Base64.encodeToString(b, Base64.NO_WRAP));
                arr.put(o);
            } catch (Exception e) { /* skip this file */ }
        }
        String text = intent.getStringExtra(Intent.EXTRA_TEXT);
        if (arr.length() == 0 && (text == null || text.isEmpty())) return false;
        pending = arr;
        pendingText = text;
        intent.setAction(Intent.ACTION_MAIN);
        if (notify && bridge != null) bridge.triggerWindowJSEvent("nfshare");
        return true;
    }

    private static String nameOf(ContentResolver cr, Uri u) {
        String n = null;
        try (Cursor c = cr.query(u, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null)) {
            if (c != null && c.moveToFirst()) n = c.getString(0);
        } catch (Exception e) { /* ignore */ }
        if (n == null || n.isEmpty()) n = u.getLastPathSegment();
        return n == null ? "file" : n;
    }

    private static byte[] readAll(InputStream in) throws Exception {
        if (in == null) return null;
        try (InputStream s = in; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[65536];
            int n, total = 0;
            while ((n = s.read(buf)) > 0) {
                total += n;
                if (total > MAX_BYTES) return null;
                out.write(buf, 0, n);
            }
            return out.toByteArray();
        }
    }

    @PluginMethod
    public void take(PluginCall call) {
        JSObject r = new JSObject();
        r.put("files", pending == null ? new JSArray() : pending);
        if (pendingText != null) r.put("text", pendingText);
        pending = null;
        pendingText = null;
        call.resolve(r);
    }

    @PluginMethod
    public void setContext(PluginCall call) { call.resolve(); }

    @PluginMethod
    public void clear(PluginCall call) { call.resolve(); }
}
