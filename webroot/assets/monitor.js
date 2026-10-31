// Local bridge - no network dependency, no CDN import. See ksu-bridge.js.
import { exec, toast, isBridgeReady } from './ksu-bridge.js';

const MODDIR = '/data/adb/modules/Turbo-Performance';
const EXCLUDE_FILE = `${MODDIR}/exclude_apps.txt`;
const TRIGGER_FILE = `${MODDIR}/trigger_apps.txt`;
// One settings file for the whole module. No drafts, no second config
// layer - the WebUI reads and writes this file directly.
const CONFIG_FILE = `${MODDIR}/config.prop`;

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

async function readConfig() {
    const cfg = {
        TRIGGER_ENABLED: 'false',
        LOWMEM_ENABLED: 'false', LOWMEM_THRESHOLD: '15'
    };
    try {
        const { errno, stdout } = await exec(`cat '${CONFIG_FILE}' 2>/dev/null`);
        if (errno === 0) {
            stdout.split('\n').forEach(line => {
                if (line.trim().startsWith('#') || !line.includes('=')) return;
                const [k, v] = line.split('=');
                if (k && v !== undefined) cfg[k.trim()] = v.trim();
            });
        }
    } catch (e) { /* use defaults */ }
    return cfg;
}

// Edits ONE key in config.prop in place and leaves the rest of the file
// (other keys, comments) untouched, instead of rewriting it from a template.
async function setConfigValue(key, value) {
    if (!/^[A-Z_]+$/.test(key) || !/^[A-Za-z0-9_.-]+$/.test(String(value))) {
        console.error('Turbo Performance: refusing to write unsafe config value', key, value);
        return;
    }
    await exec(
        `if grep -q '^${key}=' '${CONFIG_FILE}'; then ` +
        `sed -i 's/^${key}=.*/${key}=${value}/' '${CONFIG_FILE}'; ` +
        `else echo '${key}=${value}' >> '${CONFIG_FILE}'; fi`
    );
}

// ---------- Stats (RAM + ZRAM only) ----------

async function updateStats() {
    try {
        const { errno, stdout } = await exec(`sh '${MODDIR}/get_stats.sh'`);
        if (errno !== 0) return;
        const data = JSON.parse(stdout);

        if (data.memTotal) {
            const ramUsed = data.memTotal - data.memAvail;
            const ramPct = ((ramUsed / data.memTotal) * 100).toFixed(0);
            const ramAvailPct = ((data.memAvail / data.memTotal) * 100).toFixed(0);
            const totalGB = (data.memTotal / 1024 / 1024).toFixed(1);
            const usedGB = (ramUsed / 1024 / 1024).toFixed(2);
            const availGB = (data.memAvail / 1024 / 1024).toFixed(2);
            document.getElementById('ram-usage').innerText = `${usedGB} / ${totalGB} GB (${ramPct}%)`;
            document.getElementById('ram-progress').style.width = `${ramPct}%`;
            document.getElementById('ram-available').innerText = `${availGB} GB (${ramAvailPct}%)`;
        }

        if (data.swapTotal && data.swapTotal > 0) {
            const zramUsed = data.swapTotal - data.swapFree;
            const zramPct = ((zramUsed / data.swapTotal) * 100).toFixed(0);
            const zramAvailPct = ((data.swapFree / data.swapTotal) * 100).toFixed(0);
            const totalMB = (data.swapTotal / 1024).toFixed(0);
            const usedMB = (zramUsed / 1024).toFixed(0);
            const availMB = (data.swapFree / 1024).toFixed(0);
            document.getElementById('zram-usage').innerText = `${usedMB} / ${totalMB} MB (${zramPct}%)`;
            document.getElementById('zram-progress').style.width = `${zramPct}%`;
            document.getElementById('zram-available').innerText = `${availMB} MB (${zramAvailPct}%)`;
        } else {
            document.getElementById('zram-usage').innerText = 'Inactive';
            document.getElementById('zram-progress').style.width = '0%';
            document.getElementById('zram-available').innerText = 'Inactive';
        }
    } catch (e) {
        console.error('Turbo Performance: stats update failed', e);
    }
}

// ---------- Stats polling lifecycle (WebUI-driven, not a background loop) ----------
// Stats are only fetched while this page is open and visible. Closing the
// WebUI (or backgrounding the manager app) stops polling completely - there
// is no shell-side loop running stats calculations when nobody is looking.
let statsInterval = null;

function startStatsPolling() {
    if (statsInterval) return;
    updateStats();
    statsInterval = setInterval(updateStats, 3000);
}

function stopStatsPolling() {
    if (statsInterval) {
        clearInterval(statsInterval);
        statsInterval = null;
    }
}

document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        stopStatsPolling();
    } else {
        startStatsPolling();
    }
});
window.addEventListener('pagehide', stopStatsPolling);

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

// ZRAM is NOT controlled from the WebUI. To change its size, edit
// zram.prop in the module folder and reboot. The WebUI only edits the
// Trigger / Low Memory Watchdog lines in config.prop.

// ---------- Low Memory Watchdog ----------

async function loadLowMemSettings() {
    const cfg = await readConfig();
    const enabled = cfg.LOWMEM_ENABLED === 'true';
    document.getElementById('lowmem-enabled-toggle').checked = enabled;
    document.getElementById('lowmem-enabled-label').innerText = enabled ? 'Enabled' : 'Disabled';

    const threshold = String(cfg.LOWMEM_THRESHOLD || '15');
    document.querySelectorAll('#lowmem-threshold-presets .preset-chip').forEach(chip => {
        chip.classList.toggle('active', chip.dataset.value === threshold);
    });
}

async function toggleLowMem() {
    const checked = document.getElementById('lowmem-enabled-toggle').checked;
    document.getElementById('lowmem-enabled-label').innerText = checked ? 'Enabled' : 'Disabled';
    await setConfigValue('LOWMEM_ENABLED', checked ? 'true' : 'false');
    toast(checked ? 'Low memory watchdog enabled' : 'Low memory watchdog disabled');
}

async function setLowMemThreshold(value) {
    document.querySelectorAll('#lowmem-threshold-presets .preset-chip').forEach(chip => {
        chip.classList.toggle('active', chip.dataset.value === value);
    });
    await setConfigValue('LOWMEM_THRESHOLD', value);
    toast(`Watchdog threshold set to ${value}%`);
}

// ---------- Trigger (auto-close on app open) ----------

async function loadTriggerSettings() {
    const cfg = await readConfig();
    const enabled = cfg.TRIGGER_ENABLED === 'true';
    document.getElementById('trigger-enabled-toggle').checked = enabled;
    document.getElementById('trigger-enabled-label').innerText = enabled ? 'Enabled' : 'Disabled';
}

async function toggleTrigger() {
    const checked = document.getElementById('trigger-enabled-toggle').checked;
    document.getElementById('trigger-enabled-label').innerText = checked ? 'Enabled' : 'Disabled';
    await setConfigValue('TRIGGER_ENABLED', checked ? 'true' : 'false');
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

function waitForBridge(maxTries = 20) {
    return new Promise((resolve) => {
        let tries = 0;
        const check = () => {
            tries++;
            if (isBridgeReady()) {
                resolve(true);
            } else if (tries >= maxTries) {
                resolve(false);
            } else {
                setTimeout(check, 250);
            }
        };
        check();
    });
}

window.onload = async () => {
    const ready = await waitForBridge();
    if (!ready) {
        document.getElementById('ram-usage').innerText = 'Bridge unavailable';
        document.getElementById('zram-usage').innerText = 'Bridge unavailable';
        document.getElementById('action-status').innerText =
            'Could not connect to the root manager bridge (window.ksu). Try reopening the WebUI.';
        document.getElementById('action-status').className = 'hint-text status-warn';
        return;
    }

    startStatsPolling();

    loadTriggerSettings();
    loadLowMemSettings();
    refreshExcludeList();
    refreshTriggerList();

    document.getElementById('action-btn').addEventListener('click', runActionButton);

    document.getElementById('trigger-enabled-toggle').addEventListener('change', toggleTrigger);
    document.getElementById('trigger-add-btn').addEventListener('click', () => openAppPicker('trigger'));
    document.getElementById('exclude-add-btn').addEventListener('click', () => openAppPicker('exclude'));

    document.getElementById('lowmem-enabled-toggle').addEventListener('change', toggleLowMem);
    document.querySelectorAll('#lowmem-threshold-presets .preset-chip').forEach(chip => {
        chip.addEventListener('click', () => setLowMemThreshold(chip.dataset.value));
    });

    document.getElementById('app-picker-close').addEventListener('click', () => {
        document.getElementById('app-picker-modal').style.display = 'none';
    });
};
