// Turbo Performance WebUI logic (v1.7)
// Uses the official KernelSU WebUI JS API (exec/toast) loaded from esm.sh
// since this module doesn't use a JS bundler. See:
// https://www.npmjs.com/package/kernelsu
import { exec, toast } from 'https://esm.sh/kernelsu';

const MODDIR = '/data/adb/modules/Turbo-Performance';
const EXCLUDE_FILE = `${MODDIR}/exclude_apps.txt`;
const TRIGGER_FILE = `${MODDIR}/trigger_apps.txt`;
const USER_CONFIG = `${MODDIR}/user_config.prop`;

let installedAppsCache = null;
let appPickerTarget = null; // 'exclude' | 'trigger'

// ---------- Helpers ----------

async function readLines(path) {
    try {
        const { errno, stdout } = await exec(`cat '${path}' 2>/dev/null`);
        if (errno !== 0) return [];
        return stdout.split('\n').map(l => l.trim()).filter(Boolean);
    } catch (e) {
        return [];
    }
}

async function writeLines(path, lines) {
    const content = lines.join('\n');
    // Heredoc write - safe for package names (alnum + dots only)
    await exec(`cat > '${path}' << 'TURBO_EOF'\n${content}\nTURBO_EOF`);
}

async function readUserConfig() {
    const cfg = { ZRAM_MODE: 'auto', ZRAM_MANUAL_MB: '0', TRIGGER_ENABLED: 'false' };
    try {
        const { errno, stdout } = await exec(`cat '${USER_CONFIG}' 2>/dev/null`);
        if (errno === 0) {
            stdout.split('\n').forEach(line => {
                const [k, v] = line.split('=');
                if (k && v !== undefined) cfg[k.trim()] = v.trim();
            });
        }
    } catch (e) { /* use defaults */ }
    return cfg;
}

async function writeUserConfig(cfg) {
    const content = `ZRAM_MODE=${cfg.ZRAM_MODE}\nZRAM_MANUAL_MB=${cfg.ZRAM_MANUAL_MB}\nTRIGGER_ENABLED=${cfg.TRIGGER_ENABLED}`;
    await exec(`cat > '${USER_CONFIG}' << 'TURBO_EOF'\n${content}\nTURBO_EOF`);
}

// ---------- Stats (RAM + ZRAM only) ----------

async function updateStats() {
    try {
        const response = await fetch('assets/stats.json?t=' + Date.now());
        const data = await response.json();

        if (data.memTotal) {
            const ramUsed = data.memTotal - data.memAvail;
            const ramPct = ((ramUsed / data.memTotal) * 100).toFixed(0);
            const totalGB = (data.memTotal / 1024 / 1024).toFixed(1);
            const usedGB = (ramUsed / 1024 / 1024).toFixed(2);
            document.getElementById('ram-usage').innerText = `${usedGB} / ${totalGB} GB (${ramPct}%)`;
            document.getElementById('ram-progress').style.width = `${ramPct}%`;
        }

        if (data.swapTotal && data.swapTotal > 0) {
            const zramUsed = data.swapTotal - data.swapFree;
            const zramPct = ((zramUsed / data.swapTotal) * 100).toFixed(0);
            const totalMB = (data.swapTotal / 1024).toFixed(0);
            const usedMB = (zramUsed / 1024).toFixed(0);
            document.getElementById('zram-usage').innerText = `${usedMB} / ${totalMB} MB (${zramPct}%)`;
            document.getElementById('zram-progress').style.width = `${zramPct}%`;
        } else {
            document.getElementById('zram-usage').innerText = 'Inactive';
            document.getElementById('zram-progress').style.width = '0%';
        }
    } catch (e) {
        console.error('Turbo Performance: stats update failed', e);
    }
}

// ---------- Action button ----------

async function runActionButton() {
    const statusEl = document.getElementById('action-status');
    statusEl.innerText = 'Cleaning background apps...';
    try {
        const { errno, stdout } = await exec(`sh '${MODDIR}/action.sh'`);
        if (errno === 0) {
            statusEl.innerText = 'Done. Background apps closed.';
            toast('Background apps closed');
        } else {
            statusEl.innerText = 'Failed to run cleaner.';
        }
    } catch (e) {
        statusEl.innerText = 'Error: ' + e;
    }
    setTimeout(() => { statusEl.innerText = ''; }, 4000);
}

// ---------- ZRAM settings ----------

async function loadZramSettings() {
    const cfg = await readUserConfig();
    if (cfg.ZRAM_MODE === 'manual') {
        document.getElementById('zram-mode-manual').checked = true;
        document.getElementById('zram-manual-row').style.display = 'block';
        document.getElementById('zram-manual-input').value = cfg.ZRAM_MANUAL_MB || '';
    } else {
        document.getElementById('zram-mode-auto').checked = true;
        document.getElementById('zram-manual-row').style.display = 'none';
    }
}

async function saveZramSettings() {
    const mode = document.querySelector('input[name="zram-mode"]:checked').value;
    const manualVal = parseInt(document.getElementById('zram-manual-input').value, 10);
    const statusEl = document.getElementById('zram-status');

    if (mode === 'manual' && (!manualVal || manualVal < 128)) {
        statusEl.innerText = 'Enter a valid size (minimum 128 MB).';
        statusEl.className = 'hint-text status-warn';
        return;
    }

    const cfg = await readUserConfig();
    cfg.ZRAM_MODE = mode;
    cfg.ZRAM_MANUAL_MB = mode === 'manual' ? String(manualVal) : '0';
    await writeUserConfig(cfg);

    statusEl.innerText = 'Applying...';
    statusEl.className = 'hint-text';

    try {
        const { errno, stdout, stderr } = await exec(`sh '${MODDIR}/apply_zram.sh'`);
        if (errno === 0) {
            statusEl.innerText = 'ZRAM updated successfully.';
            statusEl.className = 'hint-text status-good';
            toast('ZRAM settings applied');
        } else {
            statusEl.innerText = 'Failed to apply ZRAM settings: ' + (stderr || stdout);
            statusEl.className = 'hint-text status-warn';
        }
    } catch (e) {
        statusEl.innerText = 'Error: ' + e;
        statusEl.className = 'hint-text status-warn';
    }
}

// ---------- Trigger (auto-close on app open) ----------

async function loadTriggerSettings() {
    const cfg = await readUserConfig();
    const enabled = cfg.TRIGGER_ENABLED === 'true';
    document.getElementById('trigger-enabled-toggle').checked = enabled;
    document.getElementById('trigger-enabled-label').innerText = enabled ? 'Enabled' : 'Disabled';
}

async function toggleTrigger() {
    const checked = document.getElementById('trigger-enabled-toggle').checked;
    document.getElementById('trigger-enabled-label').innerText = checked ? 'Enabled' : 'Disabled';
    const cfg = await readUserConfig();
    cfg.TRIGGER_ENABLED = checked ? 'true' : 'false';
    await writeUserConfig(cfg);
    toast(checked ? 'Auto-close trigger enabled' : 'Auto-close trigger disabled');
}

// ---------- App lists (exclude / trigger) ----------

function renderAppList(containerId, apps, onRemove) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    if (apps.length === 0) {
        container.innerHTML = '<div class="app-list-empty">No apps added yet.</div>';
        return;
    }
    apps.forEach(pkg => {
        const row = document.createElement('div');
        row.className = 'app-list-item';
        row.innerHTML = `<span>${pkg}</span><span class="remove-btn" data-pkg="${pkg}">✕</span>`;
        row.querySelector('.remove-btn').addEventListener('click', () => onRemove(pkg));
        container.appendChild(row);
    });
}

async function refreshExcludeList() {
    const apps = await readLines(EXCLUDE_FILE);
    renderAppList('exclude-apps-list', apps, async (pkg) => {
        const updated = apps.filter(p => p !== pkg);
        await writeLines(EXCLUDE_FILE, updated);
        refreshExcludeList();
    });
}

async function refreshTriggerList() {
    const apps = await readLines(TRIGGER_FILE);
    renderAppList('trigger-apps-list', apps, async (pkg) => {
        const updated = apps.filter(p => p !== pkg);
        await writeLines(TRIGGER_FILE, updated);
        refreshTriggerList();
    });
}

// ---------- App picker modal ----------

async function getInstalledApps() {
    if (installedAppsCache) return installedAppsCache;
    const { errno, stdout } = await exec('pm list packages -3');
    if (errno !== 0) return [];
    installedAppsCache = stdout.split('\n')
        .map(l => l.replace('package:', '').trim())
        .filter(Boolean)
        .sort();
    return installedAppsCache;
}

async function openAppPicker(target) {
    appPickerTarget = target;
    const modal = document.getElementById('app-picker-modal');
    const listEl = document.getElementById('app-picker-list');
    const searchEl = document.getElementById('app-picker-search');
    searchEl.value = '';
    listEl.innerHTML = '<div class="app-list-empty">Loading apps...</div>';
    modal.style.display = 'flex';

    const apps = await getInstalledApps();
    renderPickerList(apps);

    searchEl.oninput = () => {
        const q = searchEl.value.toLowerCase();
        renderPickerList(apps.filter(a => a.toLowerCase().includes(q)));
    };
}

function renderPickerList(apps) {
    const listEl = document.getElementById('app-picker-list');
    listEl.innerHTML = '';
    if (apps.length === 0) {
        listEl.innerHTML = '<div class="app-list-empty">No apps found.</div>';
        return;
    }
    apps.forEach(pkg => {
        const item = document.createElement('div');
        item.className = 'app-picker-item';
        item.innerText = pkg;
        item.addEventListener('click', () => selectAppFromPicker(pkg));
        listEl.appendChild(item);
    });
}

async function selectAppFromPicker(pkg) {
    document.getElementById('app-picker-modal').style.display = 'none';
    if (appPickerTarget === 'exclude') {
        const apps = await readLines(EXCLUDE_FILE);
        if (!apps.includes(pkg)) {
            apps.push(pkg);
            await writeLines(EXCLUDE_FILE, apps);
        }
        refreshExcludeList();
    } else if (appPickerTarget === 'trigger') {
        const apps = await readLines(TRIGGER_FILE);
        if (!apps.includes(pkg)) {
            apps.push(pkg);
            await writeLines(TRIGGER_FILE, apps);
        }
        refreshTriggerList();
    }
}

// ---------- Init ----------

window.onload = () => {
    updateStats();
    setInterval(updateStats, 3000);

    loadZramSettings();
    loadTriggerSettings();
    refreshExcludeList();
    refreshTriggerList();

    document.getElementById('action-btn').addEventListener('click', runActionButton);

    document.querySelectorAll('input[name="zram-mode"]').forEach(radio => {
        radio.addEventListener('change', () => {
            const isManual = document.getElementById('zram-mode-manual').checked;
            document.getElementById('zram-manual-row').style.display = isManual ? 'block' : 'none';
        });
    });
    document.getElementById('zram-save-btn').addEventListener('click', saveZramSettings);

    document.getElementById('trigger-enabled-toggle').addEventListener('change', toggleTrigger);
    document.getElementById('trigger-add-btn').addEventListener('click', () => openAppPicker('trigger'));
    document.getElementById('exclude-add-btn').addEventListener('click', () => openAppPicker('exclude'));

    document.getElementById('app-picker-close').addEventListener('click', () => {
        document.getElementById('app-picker-modal').style.display = 'none';
    });
};
