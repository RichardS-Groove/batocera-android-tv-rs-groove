package com.gathin.tvhome;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Android TV RS Groove (08/11/2026): the weather now, top right, where the wallpaper caption sat ("☀  24°  ·
 * Capital"). The TV's own location when Android knows one, otherwise Capital Federal (Buenos Aires); data from
 * Open-Meteo, which needs no key. Refreshed every 30 minutes while Home is on screen; without internet the last
 * value stays, and nothing shows until a first answer arrives. Based on Weather.java of the photo-screensaver
 * add-on in this repository (MIT).
 */
final class WeatherNow {
    private static final long REFRESH_MS = 30 * 60_000L;
    private static final long RETRY_MS = 5 * 60_000L;
    private static final long LOCATE_MS = 15_000L;
    private static final int TIMEOUT_MS = 8_000;
    private static final double CAPITAL_LAT = -34.61;
    private static final double CAPITAL_LON = -58.38;
    private static final String CAPITAL = "Capital";
    private static final String TAG = "WeatherNow";

    private final Context context;
    private final TextView text;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable refresh = this::refresh;
    private long lastShown;
    private boolean running;

    WeatherNow(Context context, FrameLayout root) {
        this.context = context.getApplicationContext();
        text = make(context, root);
    }

    void start() {
        running = true;
        handler.removeCallbacks(refresh);
        long wait = lastShown == 0 ? 0 : lastShown + REFRESH_MS - SystemClock.elapsedRealtime();
        handler.postDelayed(refresh, Math.max(0, wait));
    }

    void stop() {
        running = false;
        handler.removeCallbacks(refresh);
    }

    private void refresh() {
        android.util.Log.i(TAG, "refresh, running=" + running);
        if (!running) return;
        handler.removeCallbacks(refresh);
        handler.postDelayed(refresh, REFRESH_MS);
        locate(location -> {
            double lat = location != null ? location.getLatitude() : CAPITAL_LAT;
            double lon = location != null ? location.getLongitude() : CAPITAL_LON;
            String place = location != null ? null : CAPITAL;
            android.util.Log.i(TAG, "location " + (location != null ? "from Android" : "none: Capital"));
            new Thread(() -> {
                try {
                    String now = now(lat, lon);
                    String shown = place == null ? now : now + "  ·  " + place;
                    android.util.Log.i(TAG, "shown: " + shown);
                    handler.post(() -> {
                        lastShown = SystemClock.elapsedRealtime();
                        text.setText(shown);
                        text.setContentDescription(shown);
                        text.setVisibility(View.VISIBLE);
                    });
                } catch (Exception e) {
                    android.util.Log.w(TAG, "weather failed: " + e);
                    handler.post(() -> {   // no internet or an odd reply: keep the last value, try again soon
                        if (!running) return;
                        handler.removeCallbacks(refresh);
                        handler.postDelayed(refresh, RETRY_MS);
                    });
                }
            }, "weather-now").start();
        });
    }

    /** Same spot and look as the wallpaper caption (WallpaperPlayer.makeCaption), a little larger. */
    private static TextView make(Context context, FrameLayout root) {
        float dp = context.getResources().getDisplayMetrics().density;
        TextView view = new TextView(context);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 19);
        view.setTextColor(0xE6FFFFFF);
        view.setShadowLayer(6 * dp, 0, dp, 0xCC000000);
        view.setSingleLine(true);
        view.setEllipsize(TextUtils.TruncateAt.END);
        view.setMaxWidth(Math.round(520 * dp));
        view.setFocusable(false);
        view.setVisibility(View.GONE);
        try {
            view.setTypeface(UiFont.get(context, R.string.font_regular));
        } catch (Exception ignored) {
            // the system font is fine
        }
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.END);
        params.topMargin = Math.round(110 * dp);
        params.setMarginEnd(Math.round(62 * dp));
        root.addView(view, params);
        return view;
    }

    /** The newest location Android knows, or a fresh one; null when there is none within LOCATE_MS. */
    @SuppressWarnings("deprecation")
    private void locate(Consumer<Location> done) {
        AtomicBoolean answered = new AtomicBoolean();
        Consumer<Location> once = l -> {
            if (answered.compareAndSet(false, true)) handler.post(() -> done.accept(l));
        };
        LocationManager lm = context.getSystemService(LocationManager.class);
        boolean permitted = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        if (lm == null || !permitted) {
            once.accept(null);
            return;
        }
        handler.postDelayed(() -> once.accept(null), LOCATE_MS);
        try {
            Location best = null;
            for (String provider : lm.getProviders(true)) {
                Location l = lm.getLastKnownLocation(provider);
                if (l != null && (best == null || l.getTime() > best.getTime())) best = l;
            }
            if (best != null || Build.VERSION.SDK_INT < 30 || !lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                once.accept(best);
                return;
            }
            lm.getCurrentLocation(LocationManager.NETWORK_PROVIDER, null, context.getMainExecutor(), once::accept);
        } catch (SecurityException | IllegalArgumentException e) {
            once.accept(null);
        }
    }

    /** "☀  24°" for the place, blocking: call it off the main thread. */
    private static String now(double latitude, double longitude) throws Exception {
        // Two decimals is about 1 km: enough for the weather, no more of where the TV is than that.
        String url = String.format(Locale.ROOT, "https://api.open-meteo.com/v1/forecast?latitude=%.2f"
                + "&longitude=%.2f&current=temperature_2m,weather_code,is_day", latitude, longitude);
        JSONObject current = get(url).getJSONObject("current");
        int temp = (int) Math.round(current.getDouble("temperature_2m"));
        return symbol(current.getInt("weather_code"), current.optInt("is_day", 1) == 1) + "  " + temp + "°";
    }

    /** A plain symbol for a WMO weather code, from characters every TV font has. */
    private static String symbol(int code, boolean day) {
        if (code == 0 || code == 1) return day ? "☀" : "☾";   // sun, moon
        if (code == 2) return "⛅";                                  // sun behind cloud
        if (code == 3 || code == 45 || code == 48) return "☁";      // cloud (fog too)
        if (code >= 71 && code <= 77 || code == 85 || code == 86) return "❄";   // snow
        if (code >= 95) return "⚡";                                 // thunder
        return "☂";                                                 // drizzle, rain, showers
    }

    private static JSONObject get(String url) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        connection.setConnectTimeout(TIMEOUT_MS);
        connection.setReadTimeout(TIMEOUT_MS);
        try (InputStream in = connection.getInputStream()) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            for (int n; (n = in.read(buffer)) != -1; ) {
                out.write(buffer, 0, n);
                if (out.size() > 64 * 1024) throw new IOException("reply too large");
            }
            return new JSONObject(new String(out.toByteArray(), StandardCharsets.UTF_8));
        } finally {
            connection.disconnect();
        }
    }
}
