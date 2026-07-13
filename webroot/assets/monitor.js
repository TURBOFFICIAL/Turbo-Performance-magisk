async function updateSystemStats() {
    try {
        const response = await fetch('assets/stats.json?t=' + Date.now());
        const data = await response.json();

        // 1. Regular RAM
        if (data.memTotal) {
            const ramUsed = data.memTotal - data.memAvail;
            const ramPercentage = ((ramUsed / data.memTotal) * 100).toFixed(0);
            const totalGB = (data.memTotal / 1024 / 1024).toFixed(1);
            const usedGB = (ramUsed / 1024 / 1024).toFixed(2);
            document.getElementById('ram-usage').innerText = `${usedGB} / ${totalGB} GB (${ramPercentage}%)`;
            document.getElementById('ram-progress').style.width = `${ramPercentage}%`;
        }

        // 2. ZRAM
        if (data.swapTotal && data.swapTotal > 0) {
            const zramUsed = data.swapTotal - data.swapFree;
            const zramPercentage = ((zramUsed / data.swapTotal) * 100).toFixed(0);
            const totalMB = (data.swapTotal / 1024).toFixed(0);
            const usedMB = (zramUsed / 1024).toFixed(0);
            document.getElementById('zram-usage').innerText = `${usedMB} / ${totalMB} MB (${zramPercentage}%)`;
            document.getElementById('zram-progress').style.width = `${zramPercentage}%`;
        } else {
            document.getElementById('zram-usage').innerText = "Inactive / Disabled";
            document.getElementById('zram-progress').style.width = `0%`;
        }

        document.getElementById('swap-val').innerText = data.swappiness || "100";

        // 3. CPU
        if (data.cpuTemp) {
            let rawTemp = parseInt(data.cpuTemp);
            let finalTemp = rawTemp > 1000 ? (rawTemp / 1000).toFixed(1) : rawTemp.toFixed(1);
            const tElem = document.getElementById('cpu-temp');
            tElem.innerText = `${finalTemp} °C`;
            tElem.className = finalTemp > 45 ? "status-warn" : "status-good";
        }

        if (data.cpuFreq && parseInt(data.cpuFreq) > 0) {
            document.getElementById('cpu-freq').innerText = `${(parseInt(data.cpuFreq) / 1000).toFixed(0)} MHz`;
        } else {
            document.getElementById('cpu-freq').innerText = "Idle";
        }

        // Separate GPU into its own card
        const gpuValueElem = document.getElementById('gpu-freq');
        if (gpuValueElem) {
            const gpuRow = gpuValueElem.parentElement;
            const cpuCard = gpuRow.parentElement;

            const cardHeaders = cpuCard.getElementsByTagName('h3');
            if (cardHeaders.length > 0 && cardHeaders[0].innerText.includes("CPU")) {
                cardHeaders[0].innerText = "CPU Status";
            }

            let customGpuCard = document.getElementById('custom-gpu-card');
            if (!customGpuCard) {
                customGpuCard = document.createElement('div');
                customGpuCard.id = 'custom-gpu-card';
                customGpuCard.className = cpuCard.className;
                customGpuCard.style.marginTop = "15px";
                customGpuCard.innerHTML = `
                    <h3 style="color: #ffa500; font-weight: bold; margin-bottom: 12px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 6px;">
                        GPU Status
                    </h3>
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                        <span style="color: #aaa;">GPU Frequency:</span>
                        <span id="new-gpu-freq" style="font-weight: bold; color: #fff;">Reading...</span>
                    </div>
                `;
                cpuCard.parentNode.insertBefore(customGpuCard, cpuCard.nextSibling);
                gpuRow.style.display = 'none';
            }

            const newGpuLabel = document.getElementById('new-gpu-freq');
            if (newGpuLabel) {
                if (data.gpuFreq && parseInt(data.gpuFreq) > 0) {
                    let gFreq = parseInt(data.gpuFreq);
                    let finalGpu = gFreq > 1000000 ? (gFreq / 1000000).toFixed(0) : gFreq;
                    newGpuLabel.innerText = `${finalGpu} MHz`;
                } else {
                    newGpuLabel.innerText = "Idle (Sleep)";
                }
            }
        }

        // 4. Battery Data + Health & Battery Life
        if (data.batLevel) {
            document.getElementById('bat-level').innerText = `${data.batLevel}%`;
        }
        if (data.batTemp) {
            let bTemp = (parseInt(data.batTemp) / 10).toFixed(1);
            const btElem = document.getElementById('bat-temp');
            btElem.innerText = `${bTemp} °C`;
            btElem.className = bTemp > 40 ? "status-warn" : "status-good";
        }
        if (data.batNow) {
            let currentmA = Math.abs(parseInt(data.batNow) / 1000).toFixed(0);
            document.getElementById('bat-current').innerText = `${currentmA} mA`;
        }

        // ==========================================
        // 🔥 Inject Battery Health & Life Stats
        // ==========================================
        if (data.batChargeFull && data.batDesignFull) {
            const batLevelElem = document.getElementById('bat-level');
            if (batLevelElem) {
                const batCard = batLevelElem.parentElement.parentElement; // Main Battery Card
                
                let customHealthRow = document.getElementById('custom-bat-health-row');
                if (!customHealthRow) {
                    customHealthRow = document.createElement('div');
                    customHealthRow.id = 'custom-bat-health-row';
                    customHealthRow.style.display = 'flex';
                    customHealthRow.style.justifyContent = 'space-between';
                    customHealthRow.style.alignItems = 'center';
                    customHealthRow.style.marginTop = '8px';
                    customHealthRow.style.borderTop = '1px dashed rgba(255,255,255,0.1)';
                    customHealthRow.style.paddingTop = '8px';
                    customHealthRow.innerHTML = `
                        <span style="color: #aaa;">Battery Health:</span>
                        <span id="bat-health-val" style="font-weight: bold; color: #00ffcc;">Calculating...</span>
                    `;
                    // Append inside the battery card at the end
                    batCard.appendChild(customHealthRow);
                }

                // Accurate mAh calculation
                let currentMax = Math.round(parseInt(data.batChargeFull) / 1000);
                let designMax = Math.round(parseInt(data.batDesignFull) / 1000);
                
                // Correction loops for specific kernel layouts
                if (currentMax < 100) { currentMax = currentMax * 100; designMax = designMax * 100; }
                if (currentMax > 10000) { currentMax = Math.round(currentMax / 10); designMax = Math.round(designMax / 10); }

                const healthPercentage = ((currentMax / designMax) * 100).toFixed(0);

                // Displays as: "3400 / 4000 mAh (85%)"
                document.getElementById('bat-health-val').innerText = `${currentMax} / ${designMax} mAh (${healthPercentage}%)`;
            }
        }

    } catch (e) {
        console.log("Updating battery health and system stats...");
    }
}

window.onload = () => {
    updateSystemStats();
    setInterval(updateSystemStats, 2000);
};