#!/system/bin/sh

# ui_print outputs text to the screen during installation
ui_print " "
ui_print "====================================="
ui_print "       Turbo Performance 🚀          "
ui_print "====================================="
ui_print "  Author: Mahmoud (Turbo) 🔥         "
ui_print "  Version: v1.1                      "
ui_print "-------------------------------------"
ui_print "[+] Initializing core settings..."
sleep 1

# Reads configuration from config.prop if available
if [ -f "$MODPATH/config.prop" ]; then
    . "$MODPATH/config.prop"
    ui_print "[+] Target Size detected: $ZRAM_SIZE Bytes"
    ui_print "[+] Compression Algorithm: $ZRAM_ALGO"
else
    ui_print "[-] Warning: config.prop not found!"
fi

sleep 1
ui_print "-------------------------------------"
ui_print "[+] Tuning Swappiness & Memory pools..."
ui_print "[+] Disabling KSM to eliminate micro-stutters..."
sleep 1
ui_print "-------------------------------------"
ui_print "⚡ Installed Successfully! ⚡"
ui_print "🎮 Reboot your device and enjoy peak performance 🎮"
ui_print "====================================="
ui_print " "