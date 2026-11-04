#!/bin/bash
set -e

APK="/home/fervi/STA/supertuxadvance.apk"

if [ ! -f "$APK" ]; then
    echo "Error: APK not found at $APK"
    exit 1
fi

DEVICE="$(adb devices | grep -v "List" | grep -w "device" | head -n1 | awk '{print $1}')"

if [ -z "$DEVICE" ]; then
    echo "Error: No ADB device connected. Please connect your phone via USB and enable USB debugging."
    exit 1
fi

echo "Installing $APK to device $DEVICE..."
adb -s "$DEVICE" install -r "$APK"
echo "Restarting application..."
adb -s "$DEVICE" shell am force-stop org.supertuxadvance
adb -s "$DEVICE" shell am start -n org.supertuxadvance/.MainActivity
echo "Done! Follow logs with: adb -s $DEVICE logcat -s BRUX"
