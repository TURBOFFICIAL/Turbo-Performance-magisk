// Local, network-free bridge to the native KernelSU WebView interface.
// The manager app injects a `window.ksu` object into the page before it
// loads. We talk to it directly instead of importing the 'kernelsu' npm
// package from a CDN (which was unreliable inside the manager's WebView -
// dynamic module fetches can fail there, leaving the dashboard stuck on
// "Reading...").
//
// If window.ksu is missing entirely (unsupported manager / bridge not
// injected yet), every call rejects clearly instead of hanging forever.

function bridgeAvailable() {
    return typeof window.ksu !== 'undefined' && typeof window.ksu.exec === 'function';
}

export function exec(command, options = {}) {
    return new Promise((resolve, reject) => {
        if (!bridgeAvailable()) {
            reject(new Error('KernelSU bridge (window.ksu) not found'));
            return;
        }
        const cbName = '__turbo_exec_cb_' + Date.now() + '_' + Math.floor(Math.random() * 100000);
        window[cbName] = (errno, stdout, stderr) => {
            delete window[cbName];
            resolve({ errno, stdout, stderr });
        };
        try {
            window.ksu.exec(command, JSON.stringify(options), cbName);
        } catch (e) {
            delete window[cbName];
            reject(e);
        }
    });
}

export function toast(message) {
    try {
        if (bridgeAvailable() && typeof window.ksu.toast === 'function') {
            window.ksu.toast(message);
        }
    } catch (e) {
        // Non-critical - ignore if toast isn't supported
    }
}

export function isBridgeReady() {
    return bridgeAvailable();
}
