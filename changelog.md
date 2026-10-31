# v1.9 - Simplified ZRAM & Memory Control

## Changes
- **ZRAM is now set from one file:** `zram.prop` (module folder). Edit `ZRAM_SIZE_MB`, save, reboot. `0` turns ZRAM off. The WebUI no longer controls ZRAM.
- **New: Low Memory Watchdog** (off by default) - closes background apps automatically when available RAM drops below 10 / 15 / 20 / 25%.
- **Clean Background Apps** now only closes apps (it no longer touches ZRAM).
- **Fixed:** the root manager is now reliably protected from being closed (KernelSU-Next uses a randomized package name, so name matching never worked).
- **Fixed:** toggling a WebUI switch no longer erases other settings in `config.prop`.
- **Fixed:** duplicate-run protection now actually works.
- **Memory tuning:** `vm.watermark_scale_factor=200`, `vm.page-cluster=0`.
- **Storage tuning:** I/O scheduler `none`/`noop`/`deadline` and read-ahead 512 KB (applied once after boot).
- Lower idle overhead: Auto-Close and Watchdog loops do almost nothing while disabled.

## Update notes
- Reboot after updating.
- Your `exclude_apps.txt` and `trigger_apps.txt` are not touched.
- If you edited ZRAM before: set your size in `zram.prop` (the old `ZRAM_SIZE` line in `config.prop` is gone).
