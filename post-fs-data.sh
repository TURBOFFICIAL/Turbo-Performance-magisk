#!/system/bin/sh
MODDIR=${0%/*}

# --- الأوامر الموجودة أصلاً سيبها زي ما هي ---
# (هتلاقي أكواد تانية مكتوبة فيه، ما تمسحهاش)

# الإجبار النهائي (تعديل القيم لتطابق التحديث الجديد ⚡)
sysctl -w vm.swappiness=60
echo 0 > /sys/kernel/mm/ksm/run

# إعدادات الذاكرة الإضافية المحسنة بالملي
sysctl -w vm.page-cluster=0
sysctl -w vm.dirty_ratio=20
sysctl -w vm.dirty_background_ratio=5
sysctl -w vm.vfs_cache_pressure=200
