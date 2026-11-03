package org.supertuxadvance;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class AssetExtractor {
    private static final String TAG = "STA_AssetExtractor";
    private static final String PREFS_NAME = "STA_PREFS";
    private static final String KEY_VERSION = "extracted_version";
    public static final int ASSET_VERSION = 4;

    public static void extractAssetsIfNeeded(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        int currentVersion = prefs.getInt(KEY_VERSION, 0);

        File gameDir = context.getFilesDir();
        File gameBrx = new File(gameDir, "game.brx");

        if (gameBrx.exists() && currentVersion == ASSET_VERSION) {
            Log.i(TAG, "Assets already up to date (version " + currentVersion + ")");
            return;
        }

        Log.i(TAG, "Extracting game assets to " + gameDir.getAbsolutePath() + "...");
        gameDir.mkdirs();

        try (InputStream is = context.getAssets().open("game.zip");
             ZipInputStream zis = new ZipInputStream(is)) {
            ZipEntry entry;
            byte[] buffer = new byte[65536];
            while ((entry = zis.getNextEntry()) != null) {
                File outFile = new File(gameDir, entry.getName());
                if (entry.isDirectory()) {
                    outFile.mkdirs();
                } else {
                    File parent = outFile.getParentFile();
                    if (parent != null && !parent.exists()) {
                        parent.mkdirs();
                    }
                    try (FileOutputStream fos = new FileOutputStream(outFile)) {
                        int len;
                        while ((len = zis.read(buffer)) > 0) {
                            fos.write(buffer, 0, len);
                        }
                    }
                }
                zis.closeEntry();
            }
            prefs.edit().putInt(KEY_VERSION, ASSET_VERSION).apply();
            Log.i(TAG, "Asset extraction completed successfully.");
        } catch (Exception e) {
            Log.e(TAG, "Failed to extract assets", e);
        }
    }
}
