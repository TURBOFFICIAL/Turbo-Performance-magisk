#!/system/bin/sh

# أمر ui_print هو اللي بيطبع الكلام على الشاشة أثناء التسطيب
ui_print " "
ui_print "====================================="
ui_print "    Performance module   "
ui_print "====================================="
ui_print "  Author: Turbo☝️🔥                  "
ui_print "  Version: v1.0                      "
ui_print "------------------------------------"
ui_print "[+] جاري تهيئة الإعدادات..."
sleep 1

# تقدر تخلي السكربت يقرأ القيم من ملف الـ config.prop ويطبعها للمستخدم
if [ -f "$MODPATH/config.prop" ]; then
    . "$MODPATH/config.prop"
    ui_print "[+] تم تحديد الحجم: $ZRAM_SIZE Bytes"
    ui_print "[+] تم اختيار الخوارزمية: $ZRAM_ALGO"
else
    ui_print "[-] تحذير: ملف config.prop غير موجود!"
fi

sleep 1
ui_print "------------------------------------"
ui_print "[+] جاري ضبط إعدادات الـ Swappiness والألعاب..."
ui_print "[+] جاري إيقاف الـ KSM لمنع الـ Lag والحرارة..."
sleep 1
ui_print "------------------------------------"
ui_print "⚡ تم التسطيب بنجاج! ⚡"
ui_print "🎮 اعمل ريستارت وعيش الأداء الفاجر 🎮"
ui_print "====================================="
ui_print " "
