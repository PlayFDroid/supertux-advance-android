package org.supertuxadvance;

import org.libsdl.app.SDLActivity;
import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.util.Log;

public class MainActivity extends SDLActivity {
    private static final String TAG = "STA_MainActivity";

    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "main"
        };
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        setVolumeControlStream(android.media.AudioManager.STREAM_MUSIC);
        Log.i(TAG, "onCreate: extracting assets if needed...");
        AssetExtractor.extractAssetsIfNeeded(this);
        super.onCreate(savedInstanceState);
    }

    @Override
    public void setOrientationBis(int w, int h, boolean resizable, String hint) {
        // Enforce landscape orientation strictly at all times
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        System.exit(0);
    }
}
