#!/system/bin/sh
MODDIR=${0%/*}

# --- الأوامر الموجودة أصلاً سيبها زي ما هي ---
# (هتلاقي أكواد تانية مكتوبة فيه، ما تمسحهاش)

# الإجبار النهائي
sysctl -w vm.swappiness=160
echo 0 > /sys/kernel/mm/ksm/run


# إعدادات الذاكرة الإضافية
sysctl -w vm.page-cluster=0
sysctl -w vm.dirty_ratio=30
sysctl -w vm.dirty_background_ratio=10
sysctl -w vm.vfs_cache_pressure=125
