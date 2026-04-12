enum WebDashboardHTML {
    static let page = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>BLE Thermo</title>
        <script>document.title = localStorage.getItem('bleTitle') || 'BLE Thermo';</script>
        <!-- title applied immediately from localStorage while server fetch is in flight -->
        <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect x='13' y='3' width='6' height='19' rx='3' fill='black'/%3E%3Ccircle cx='16' cy='25' r='6' fill='black'/%3E%3Crect x='14.5' y='4.5' width='3' height='11' fill='white'/%3E%3C/svg%3E">
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
        <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3"></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro", system-ui, sans-serif;
                background: #1a1a2e;
                color: #e0e0e0;
                min-height: 100vh;
                padding: 24px;
            }
            .container { max-width: 960px; margin: 0 auto; }
            h1 {
                font-size: 1.5rem;
                font-weight: 600;
                margin-bottom: 16px;
                color: #fff;
                cursor: pointer;
                display: inline-block;
            }
            h1:hover { opacity: 0.8; }
            h1[contenteditable="true"] {
                outline: none;
                border-bottom: 2px solid rgba(74,158,255,0.7);
                cursor: text;
                padding-bottom: 2px;
                opacity: 1;
            }
            /* Tab bar */
            .tab-bar {
                display: flex;
                gap: 0;
                margin-bottom: 20px;
                border-bottom: 1px solid rgba(255,255,255,0.1);
            }
            .tab-btn {
                padding: 8px 22px;
                border: none;
                border-bottom: 2px solid transparent;
                background: none;
                color: rgba(255,255,255,0.45);
                font-size: 14px;
                font-weight: 500;
                cursor: pointer;
                transition: all 0.15s;
                margin-bottom: -1px;
                letter-spacing: 0.01em;
            }
            .tab-btn:hover { color: rgba(255,255,255,0.8); }
            .tab-btn.active { color: #fff; border-bottom-color: #4A9EFF; }
            .tab-content { display: none; }
            .tab-content.active { display: block; }
            /* Charts tab */
            .range-picker {
                display: flex;
                gap: 4px;
                margin-bottom: 16px;
                flex-wrap: wrap;
            }
            .range-btn {
                padding: 6px 14px;
                border: 1px solid rgba(255,255,255,0.15);
                border-radius: 8px;
                background: rgba(255,255,255,0.05);
                color: rgba(255,255,255,0.7);
                font-size: 13px;
                cursor: pointer;
                transition: all 0.15s;
            }
            .range-btn:hover { background: rgba(255,255,255,0.1); }
            .range-btn.active {
                background: rgba(74,158,255,0.25);
                border-color: rgba(74,158,255,0.5);
                color: #fff;
            }
            .controls-row {
                display: flex;
                gap: 12px;
                align-items: flex-start;
                margin-bottom: 16px;
            }
            .controls-row .range-picker { margin-bottom: 0; }
            .sensor-select {
                padding: 6px 14px;
                padding-right: 30px;
                border: 1px solid rgba(255,255,255,0.15);
                border-radius: 8px;
                background: rgba(255,255,255,0.08);
                color: #fff;
                font-size: 13px;
                cursor: pointer;
                appearance: none;
                -webkit-appearance: none;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='rgba(255,255,255,0.6)' viewBox='0 0 16 16'%3E%3Cpath d='M8 11L3 6h10z'/%3E%3C/svg%3E");
                background-repeat: no-repeat;
                background-position: right 10px center;
                flex-shrink: 0;
            }
            .sensor-select:focus {
                outline: none;
                border-color: rgba(74,158,255,0.5);
            }
            .sensor-select option { background: #1a1a2e; color: #e0e0e0; }
            .fav-btn {
                padding: 6px 10px;
                border: 1px solid rgba(255,255,255,0.15);
                border-radius: 8px;
                background: rgba(255,255,255,0.05);
                color: rgba(255,200,50,0.8);
                font-size: 15px;
                cursor: pointer;
                transition: all 0.15s;
                flex-shrink: 0;
                line-height: 1;
            }
            .fav-btn:hover { background: rgba(255,255,255,0.1); }
            .fav-btn.active {
                background: rgba(255,200,50,0.15);
                border-color: rgba(255,200,50,0.4);
                color: #FFC832;
            }
            .chart-card {
                background: rgba(255,255,255,0.04);
                border: 1px solid rgba(255,255,255,0.08);
                border-radius: 12px;
                padding: 20px;
                margin-bottom: 16px;
            }
            .chart-card h2 {
                font-size: 0.95rem;
                font-weight: 600;
                margin-bottom: 12px;
                color: rgba(255,255,255,0.85);
            }
            .chart-wrap { position: relative; height: 260px; }
            .loading {
                text-align: center;
                padding: 40px;
                color: rgba(255,255,255,0.4);
                font-size: 14px;
            }
            .main-layout {
                display: flex;
                gap: 16px;
                align-items: flex-start;
            }
            .charts-col { flex: 1; min-width: 0; }
            .current-panel {
                display: none;
                width: 220px;
                flex-shrink: 0;
                position: sticky;
                top: 24px;
                background: rgba(255,255,255,0.04);
                border: 1px solid rgba(255,255,255,0.08);
                border-radius: 12px;
                padding: 16px;
            }
            .current-panel h2 {
                font-size: 0.85rem;
                font-weight: 600;
                color: rgba(255,255,255,0.6);
                text-transform: uppercase;
                letter-spacing: 0.06em;
                margin-bottom: 12px;
            }
            .current-sensor-row {
                display: flex;
                align-items: baseline;
                justify-content: space-between;
                padding: 7px 0;
                border-bottom: 1px solid rgba(255,255,255,0.06);
                gap: 8px;
            }
            .current-sensor-row:last-child { border-bottom: none; }
            .current-sensor-name {
                font-size: 12px;
                color: rgba(255,255,255,0.6);
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                flex: 1;
            }
            .current-sensor-temp {
                font-size: 15px;
                font-weight: 600;
                color: #fff;
                white-space: nowrap;
            }
            .current-sensor-hum {
                font-size: 11px;
                color: rgba(255,255,255,0.4);
                white-space: nowrap;
            }
            .current-dot {
                width: 7px;
                height: 7px;
                border-radius: 50%;
                flex-shrink: 0;
                margin-right: 2px;
            }
            @media (min-width: 900px) {
                .container { max-width: 1160px; }
                .current-panel { display: block; }
            }

            /* ── Floor Plan tab ─────────────────────────────────── */
            .fp-toolbar {
                display: flex;
                gap: 8px;
                align-items: center;
                margin-bottom: 16px;
                flex-wrap: wrap;
            }
            .fp-toolbar-spacer { flex: 1; }
            .fp-btn {
                padding: 6px 16px;
                border: 1px solid rgba(255,255,255,0.15);
                border-radius: 8px;
                background: rgba(255,255,255,0.05);
                color: rgba(255,255,255,0.8);
                font-size: 13px;
                cursor: pointer;
                transition: all 0.15s;
                white-space: nowrap;
            }
            .fp-btn:hover { background: rgba(255,255,255,0.1); }
            .fp-btn.primary {
                background: rgba(74,158,255,0.2);
                border-color: rgba(74,158,255,0.4);
                color: #4A9EFF;
            }
            .fp-btn.primary:hover { background: rgba(74,158,255,0.3); }
            .fp-btn.danger {
                background: rgba(248,113,113,0.1);
                border-color: rgba(248,113,113,0.3);
                color: #F87171;
            }
            .fp-upload-area {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 12px;
                min-height: 300px;
                border: 2px dashed rgba(255,255,255,0.12);
                border-radius: 16px;
                color: rgba(255,255,255,0.4);
                font-size: 14px;
                cursor: pointer;
                transition: all 0.2s;
            }
            .fp-upload-area:hover, .fp-upload-area.drag-over {
                border-color: rgba(74,158,255,0.5);
                background: rgba(74,158,255,0.05);
                color: rgba(255,255,255,0.7);
            }
            .fp-upload-icon {
                font-size: 48px;
                opacity: 0.4;
                line-height: 1;
            }
            /* Image area */
            .fp-image-area { position: relative; }
            .fp-image-wrap {
                position: relative;
                display: inline-block;
                max-width: 100%;
                border-radius: 12px;
                overflow: hidden;
                background: rgba(0,0,0,0.3);
                cursor: crosshair;
                user-select: none;
            }
            .fp-image-wrap.view-mode { cursor: default; }
            .fp-image {
                display: block;
                max-width: 100%;
                max-height: 70vh;
                object-fit: contain;
                pointer-events: none;
            }
            .fp-pins-layer {
                position: absolute;
                inset: 0;
                pointer-events: none;
            }
            /* Sensor pins */
            .fp-pin {
                position: absolute;
                transform: translate(-50%, -50%);
                display: flex;
                flex-direction: column;
                align-items: center;
                pointer-events: all;
                z-index: 10;
                transition: transform 0.05s;
            }
            .fp-pin.dragging { z-index: 100; transition: none; opacity: 0.85; }
            .fp-pin-label {
                background: rgba(15,15,30,0.88);
                border: 1px solid rgba(255,255,255,0.12);
                border-left-width: 3px;
                border-radius: 7px;
                padding: 4px 8px;
                white-space: nowrap;
                font-size: 11px;
                line-height: 1.5;
                text-align: center;
                backdrop-filter: blur(8px);
                pointer-events: none;
                box-shadow: 0 2px 10px rgba(0,0,0,0.45);
            }
            .fp-pin-name {
                display: block;
                color: rgba(255,255,255,0.7);
                font-size: 10px;
                margin-bottom: 1px;
            }
            .fp-pin-readings {
                display: flex;
                gap: 5px;
                align-items: baseline;
                justify-content: center;
            }
            .fp-pin-temp { color: #fff; font-weight: 600; font-size: 13px; }
            .fp-pin-hum { color: rgba(255,255,255,0.45); font-size: 10px; }
            .fp-pin-remove {
                position: absolute;
                top: -5px;
                right: -22px;
                width: 18px; height: 18px;
                border-radius: 50%;
                background: #F87171;
                border: none;
                color: white;
                font-size: 13px;
                font-weight: bold;
                cursor: pointer;
                line-height: 1;
                display: flex; align-items: center; justify-content: center;
                box-shadow: 0 1px 4px rgba(0,0,0,0.4);
                pointer-events: all;
            }
            .fp-pin.edit-mode { cursor: grab; }
            .fp-pin.edit-mode:active { cursor: grabbing; }
            .fp-pin.selected .fp-pin-label {
                box-shadow: 0 0 0 2px rgba(74,158,255,0.6), 0 2px 10px rgba(0,0,0,0.45);
            }
            /* Unplaced sensors panel */
            .fp-unplaced-panel {
                margin-top: 16px;
                background: rgba(255,255,255,0.03);
                border: 1px solid rgba(255,255,255,0.07);
                border-radius: 12px;
                padding: 14px 16px;
            }
            .fp-unplaced-label {
                font-size: 11px;
                font-weight: 600;
                color: rgba(255,255,255,0.4);
                text-transform: uppercase;
                letter-spacing: 0.07em;
                margin-bottom: 10px;
            }
            .fp-unplaced-chips { display: flex; flex-wrap: wrap; gap: 6px; }
            .fp-chip {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 5px 12px;
                border-radius: 20px;
                border: 1px solid rgba(255,255,255,0.13);
                background: rgba(255,255,255,0.05);
                cursor: pointer;
                font-size: 12px;
                color: rgba(255,255,255,0.75);
                transition: all 0.15s;
            }
            .fp-chip:hover {
                background: rgba(74,158,255,0.12);
                border-color: rgba(74,158,255,0.35);
                color: #fff;
            }
            .fp-chip.selected {
                background: rgba(74,158,255,0.2);
                border-color: rgba(74,158,255,0.5);
                color: #4A9EFF;
            }
            .fp-chip-dot {
                width: 8px; height: 8px;
                border-radius: 50%;
                flex-shrink: 0;
            }
            .fp-hint {
                margin-top: 10px;
                font-size: 12px;
                color: rgba(255,255,255,0.35);
                font-style: italic;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1 id="pageTitle" title="Click to rename"></h1>

            <div class="tab-bar">
                <button class="tab-btn" onclick="switchTab('charts')">Charts</button>
                <button class="tab-btn active" onclick="switchTab('floorplan')">Floor Plan</button>
            </div>

            <!-- Charts Tab -->
            <div id="tab-charts" class="tab-content">
                <div class="controls-row">
                    <div class="range-picker" id="rangePicker"></div>
                    <select class="sensor-select" id="sensorSelect">
                        <option value="">All Sensors</option>
                    </select>
                    <button class="fav-btn" id="favBtn" title="Add to favorites">&#9733;</button>
                </div>
                <div class="main-layout">
                    <div class="charts-col">
                        <div class="chart-card">
                            <h2>Temperature (&deg;F)</h2>
                            <div class="chart-wrap"><canvas id="tempChart"></canvas></div>
                        </div>
                        <div class="chart-card">
                            <h2>Humidity (%)</h2>
                            <div class="chart-wrap"><canvas id="humChart"></canvas></div>
                        </div>
                    </div>
                    <div class="current-panel" id="currentPanel">
                        <h2>Current</h2>
                        <div id="currentReadings"></div>
                    </div>
                </div>
            </div>

            <!-- Floor Plan Tab -->
            <div id="tab-floorplan" class="tab-content active">
                <div class="fp-toolbar" id="fpToolbar">
                    <div class="fp-toolbar-spacer"></div>
                    <button class="fp-btn primary" id="fpEditBtn" onclick="toggleFpEdit()" style="display:none">Edit Layout</button>
                    <label class="fp-btn" id="fpUploadLabel" style="cursor:pointer; display:none">
                        Change Image
                        <input type="file" id="fpFileInput" accept="image/*" style="display:none" onchange="handleFloorPlanUpload(event)">
                    </label>
                </div>
                <div id="fpContent">
                    <!-- Upload area (shown when no image) -->
                    <label class="fp-upload-area" id="fpUploadArea" for="fpFileInputMain">
                        <span class="fp-upload-icon">&#127968;</span>
                        <span>Upload a floor plan image</span>
                        <span style="font-size:12px;opacity:0.6">JPG, PNG, or any image file</span>
                        <input type="file" id="fpFileInputMain" accept="image/*" style="display:none" onchange="handleFloorPlanUpload(event)">
                    </label>
                    <!-- Image + pins (shown when image exists) -->
                    <div class="fp-image-area" id="fpImageArea" style="display:none">
                        <div class="fp-image-wrap view-mode" id="fpImageWrap">
                            <img class="fp-image" id="fpImage" src="" alt="Floor Plan">
                            <div class="fp-pins-layer" id="fpPinsLayer"></div>
                        </div>
                        <div class="fp-unplaced-panel" id="fpUnplacedPanel" style="display:none">
                            <div class="fp-unplaced-label">Unplaced Sensors — click a sensor then click on the map to place it</div>
                            <div class="fp-unplaced-chips" id="fpUnplacedChips"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <script>
        // ── Tab switching ────────────────────────────────────────────
        function switchTab(name) {
            document.querySelectorAll('.tab-btn').forEach((btn, i) => {
                const tabs = ['charts','floorplan'];
                btn.classList.toggle('active', tabs[i] === name);
            });
            document.querySelectorAll('.tab-content').forEach(el => {
                el.classList.toggle('active', el.id === 'tab-' + name);
            });
            if (name === 'floorplan') renderFloorPlan();
        }

        // ── Shared state ─────────────────────────────────────────────
        const COLORS = [
            '#4A9EFF','#34D399','#F472B6','#FBBF24',
            '#A78BFA','#F87171','#38BDF8','#FB923C'
        ];
        let allSensors = [];
        let sensorColorMap = {};
        let latestReadings = {};  // { name: { temp, hum } }

        // ── Floor plan state ─────────────────────────────────────────
        let fpPositions = {};       // { name: { x, y } } 0-1 range
        let fpHasImage = false;
        let fpEditMode = false;
        let fpSelectedSensor = null;

        // ── Title editing ────────────────────────────────────────────
        const titleEl = document.getElementById('pageTitle');
        const DEFAULT_TITLE = 'BLE Thermo';

        titleEl.textContent = localStorage.getItem('bleTitle') || DEFAULT_TITLE;
        fetch('/api/title')
            .then(r => r.json())
            .then(d => {
                const t = d.title || DEFAULT_TITLE;
                titleEl.textContent = t;
                document.title = t;
                localStorage.setItem('bleTitle', t);
            })
            .catch(() => {});

        titleEl.onclick = () => {
            titleEl.contentEditable = 'true';
            titleEl.focus();
            const range = document.createRange();
            range.selectNodeContents(titleEl);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
        };

        function commitTitle() {
            titleEl.contentEditable = 'false';
            const newTitle = titleEl.textContent.trim() || DEFAULT_TITLE;
            titleEl.textContent = newTitle;
            document.title = newTitle;
            localStorage.setItem('bleTitle', newTitle);
            fetch('/api/title', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ title: newTitle })
            }).catch(() => {});
        }

        titleEl.onblur = commitTitle;
        titleEl.onkeydown = e => {
            if (e.key === 'Enter') { e.preventDefault(); titleEl.blur(); }
            if (e.key === 'Escape') {
                titleEl.textContent = localStorage.getItem('bleTitle') || DEFAULT_TITLE;
                titleEl.contentEditable = 'false';
            }
        };

        // ── Charts tab ───────────────────────────────────────────────
        const RANGES = [
            { key: 'hour',      label: '1 Hour' },
            { key: '6h',        label: '6 Hours' },
            { key: 'today',     label: 'Today' },
            { key: 'yesterday', label: 'Yesterday' },
            { key: 'day',       label: '1 Day' },
            { key: 'month',     label: '1 Month' },
            { key: 'year',      label: '1 Year' }
        ];

        let favorites = new Set(JSON.parse(localStorage.getItem('bleFavorites') || '[]'));
        let currentRange = 'day';
        let currentSensor = favorites.size > 0 ? '__favorites__' : '';
        let tempChart = null;
        let humChart = null;

        function saveFavorites() {
            localStorage.setItem('bleFavorites', JSON.stringify([...favorites]));
        }

        const sensorSelect = document.getElementById('sensorSelect');
        const favBtn = document.getElementById('favBtn');

        sensorSelect.onchange = () => {
            currentSensor = sensorSelect.value;
            updateFavBtn();
            loadData();
        };

        favBtn.onclick = () => {
            if (!currentSensor || currentSensor === '__favorites__') return;
            if (favorites.has(currentSensor)) {
                favorites.delete(currentSensor);
            } else {
                favorites.add(currentSensor);
            }
            saveFavorites();
            renderSensorSelect();
            updateFavBtn();
        };

        function updateFavBtn() {
            const isSpecific = currentSensor && currentSensor !== '__favorites__';
            if (!isSpecific) {
                favBtn.style.display = 'none';
            } else {
                favBtn.style.display = 'inline-block';
                if (favorites.has(currentSensor)) {
                    favBtn.classList.add('active');
                    favBtn.title = 'Remove from favorites';
                } else {
                    favBtn.classList.remove('active');
                    favBtn.title = 'Add to favorites';
                }
            }
        }

        const picker = document.getElementById('rangePicker');
        RANGES.forEach(r => {
            const btn = document.createElement('button');
            btn.className = 'range-btn' + (r.key === currentRange ? ' active' : '');
            btn.textContent = r.label;
            btn.onclick = () => {
                currentRange = r.key;
                picker.querySelectorAll('.range-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                loadData();
            };
            picker.appendChild(btn);
        });

        function timeUnit(range) {
            switch (range) {
                case 'hour': case '6h': return 'minute';
                case 'today': case 'yesterday': case 'day': return 'hour';
                case 'month': return 'day';
                case 'year': return 'month';
                default: return 'hour';
            }
        }

        function buildDatasets(seriesData) {
            const datasets = Object.entries(seriesData)
                .map(([name, points]) => ({
                    label: name,
                    data: points.map(p => ({ x: p.t * 1000, y: p.v })),
                    borderColor: sensorColorMap[name] || '#4A9EFF',
                    backgroundColor: (sensorColorMap[name] || '#4A9EFF') + '18',
                    tension: 0.4,
                    pointRadius: 0,
                    borderWidth: 2,
                    fill: false
                }));

            if (currentSensor && datasets.length === 1) {
                const pts = datasets[0].data.map(p => p.y);
                if (pts.length > 0) {
                    const avg = pts.reduce((a, b) => a + b, 0) / pts.length;
                    const color = datasets[0].borderColor;
                    const xMin = datasets[0].data[0].x;
                    const xMax = datasets[0].data[datasets[0].data.length - 1].x;
                    datasets.push({
                        label: 'avg ' + avg.toFixed(1),
                        data: [{ x: xMin, y: avg }, { x: xMax, y: avg }],
                        borderColor: color,
                        backgroundColor: 'transparent',
                        borderWidth: 1,
                        borderDash: [6, 4],
                        pointRadius: 0,
                        tension: 0,
                        fill: false,
                        order: -1,
                        isAvgLine: true
                    });
                }
            }
            return datasets;
        }

        function addTempReferenceLines(datasets) {
            let xMin = Infinity, xMax = -Infinity;
            datasets.forEach(ds => {
                if (ds.data.length > 0) {
                    xMin = Math.min(xMin, ds.data[0].x);
                    xMax = Math.max(xMax, ds.data[ds.data.length - 1].x);
                }
            });
            if (!isFinite(xMin)) return;
            [70, 80].forEach(temp => {
                datasets.push({
                    label: temp + '\\u{00B0}F',
                    data: [{ x: xMin, y: temp }, { x: xMax, y: temp }],
                    borderColor: 'rgba(255,255,255,0.22)',
                    backgroundColor: 'transparent',
                    borderWidth: 1,
                    borderDash: [4, 4],
                    pointRadius: 0,
                    tension: 0,
                    fill: false,
                    order: -1,
                    isRefLine: true
                });
            });
        }

        function legendClickHandler(e, legendItem, legend) {
            const label = legendItem.text;
            const chart = legend.chart;
            const index = chart.data.datasets.findIndex(ds => ds.label === label);
            if (index === -1) return;
            if (chart.data.datasets[index].isAvgLine || chart.data.datasets[index].isRefLine) {
                const meta = chart.getDatasetMeta(index);
                meta.hidden = !meta.hidden;
                chart.update('none');
                return;
            }
            const meta = chart.getDatasetMeta(index);
            meta.hidden = !meta.hidden;
            chart.update('none');
            const otherChart = chart === tempChart ? humChart : tempChart;
            if (otherChart) {
                const otherIndex = otherChart.data.datasets.findIndex(ds => ds.label === label);
                if (otherIndex !== -1) {
                    otherChart.getDatasetMeta(otherIndex).hidden = meta.hidden;
                    otherChart.update('none');
                }
            }
        }

        function makeChart(canvas, datasets, unit) {
            return new Chart(canvas, {
                type: 'line',
                data: { datasets },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    interaction: { mode: 'index', intersect: false },
                    plugins: {
                        legend: {
                            position: 'bottom',
                            labels: { color: 'rgba(255,255,255,0.7)', boxWidth: 12, padding: 16 },
                            onClick: legendClickHandler
                        },
                        tooltip: {
                            mode: 'index',
                            intersect: false,
                            backgroundColor: 'rgba(30,30,50,0.95)',
                            titleColor: 'rgba(255,255,255,0.6)',
                            bodyColor: '#fff',
                            borderColor: 'rgba(255,255,255,0.1)',
                            borderWidth: 1,
                            cornerRadius: 8,
                            padding: 10,
                            callbacks: {
                                label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1)
                            }
                        }
                    },
                    scales: {
                        x: {
                            type: 'time',
                            time: { unit: unit, tooltipFormat: 'PPp' },
                            ticks: { color: 'rgba(255,255,255,0.5)', maxTicksLimit: 8 },
                            grid: { color: 'rgba(255,255,255,0.06)' }
                        },
                        y: {
                            ticks: { color: 'rgba(255,255,255,0.5)' },
                            grid: { color: 'rgba(255,255,255,0.06)' }
                        }
                    }
                }
            });
        }

        function updateChart(chart, datasets, unit) {
            const hiddenByLabel = {};
            chart.data.datasets.forEach((ds, i) => {
                if (!ds.isAvgLine) hiddenByLabel[ds.label] = !chart.isDatasetVisible(i);
            });
            chart.data.datasets = datasets;
            chart.options.scales.x.time.unit = unit;
            chart.data.datasets.forEach((ds, i) => {
                const meta = chart.getDatasetMeta(i);
                meta.hidden = hiddenByLabel[ds.label] || false;
            });
            chart.update('none');
        }

        function renderSensorSelect() {
            sensorSelect.innerHTML = '<option value="">All Sensors</option>';
            if (favorites.size > 0) {
                const favOpt = document.createElement('option');
                favOpt.value = '__favorites__';
                favOpt.textContent = 'Favorites';
                sensorSelect.appendChild(favOpt);
            } else if (currentSensor === '__favorites__') {
                currentSensor = '';
            }
            allSensors.forEach(name => {
                const opt = document.createElement('option');
                opt.value = name;
                opt.textContent = name;
                sensorSelect.appendChild(opt);
            });
            sensorSelect.value = currentSensor;
            updateFavBtn();
        }

        async function loadSensors() {
            try {
                const resp = await fetch('/api/sensors');
                const data = await resp.json();
                allSensors = data.sensors;
                allSensors.forEach((name, i) => {
                    sensorColorMap[name] = COLORS[i % COLORS.length];
                });
                renderSensorSelect();
            } catch (e) {
                console.error('Failed to load sensors:', e);
            }
        }

        async function loadData() {
            try {
                let url = '/api/data?range=' + currentRange;
                const showingFavorites = currentSensor === '__favorites__';
                if (currentSensor && !showingFavorites) url += '&sensor=' + encodeURIComponent(currentSensor);
                const resp = await fetch(url);
                const data = await resp.json();
                const unit = timeUnit(currentRange);

                let tempData = data.temperature;
                let humData = data.humidity;
                if (showingFavorites) {
                    tempData = Object.fromEntries(Object.entries(tempData).filter(([k]) => favorites.has(k)));
                    humData = Object.fromEntries(Object.entries(humData).filter(([k]) => favorites.has(k)));
                }

                // Update latest readings for floor plan pins
                // Only update sensors present in the response so that chart filtering
                // doesn't wipe out readings for sensors not included in the API result.
                allSensors.forEach(name => {
                    const tPts = data.temperature[name];
                    const hPts = data.humidity[name];
                    if (tPts !== undefined || hPts !== undefined) {
                        latestReadings[name] = {
                            temp: tPts && tPts.length > 0 ? tPts[tPts.length - 1].v : null,
                            hum:  hPts && hPts.length > 0 ? hPts[hPts.length - 1].v : null
                        };
                    }
                });

                const tempDS = buildDatasets(tempData);
                if (!currentSensor || currentSensor === '__favorites__') addTempReferenceLines(tempDS);
                const humDS = buildDatasets(humData);

                if (!tempChart) {
                    tempChart = makeChart(document.getElementById('tempChart'), tempDS, unit);
                    humChart = makeChart(document.getElementById('humChart'), humDS, unit);
                } else {
                    updateChart(tempChart, tempDS, unit);
                    updateChart(humChart, humDS, unit);
                }
                renderCurrentReadings(data.temperature, data.humidity);

                // Refresh floor plan pins if visible
                if (document.getElementById('tab-floorplan').classList.contains('active')) {
                    renderFpPins();
                }
            } catch (e) {
                console.error('Failed to load data:', e);
            }
        }

        function renderCurrentReadings(tempData, humData) {
            const container = document.getElementById('currentReadings');
            const rows = allSensors
                .map(name => {
                    const tPts = tempData[name];
                    const hPts = humData[name];
                    const temp = tPts && tPts.length > 0 ? tPts[tPts.length - 1].v : null;
                    const hum  = hPts && hPts.length > 0 ? hPts[hPts.length - 1].v : null;
                    return { name, temp, hum };
                })
                .filter(r => r.temp !== null)
                .sort((a, b) => b.temp - a.temp);

            container.innerHTML = rows.map(r => {
                const color = sensorColorMap[r.name] || '#4A9EFF';
                const humStr = r.hum !== null ? r.hum.toFixed(0) + '%' : '';
                return `<div class="current-sensor-row">
                    <span class="current-dot" style="background:${color}"></span>
                    <span class="current-sensor-name" title="${r.name}">${r.name}</span>
                    <span class="current-sensor-hum">${humStr}</span>
                    <span class="current-sensor-temp">${r.temp.toFixed(1)}&deg;</span>
                </div>`;
            }).join('');
        }

        // ── Floor Plan tab ───────────────────────────────────────────

        async function initFloorPlan() {
            // Load positions
            try {
                const r = await fetch('/api/floorplan/positions');
                fpPositions = await r.json();
            } catch (e) { fpPositions = {}; }

            // Check if image exists
            try {
                const r = await fetch('/api/floorplan', { method: 'HEAD' });
                // HEAD not supported by our server; try GET with a range check via a small fetch
                // We'll just try GET and see if it's 404
            } catch (e) {}
        }

        async function renderFloorPlan() {
            // Check image presence by attempting to load it
            const img = document.getElementById('fpImage');
            if (!fpHasImage) {
                // Try fetching — we cache-bust to force a check
                const test = await fetch('/api/floorplan?_=' + Date.now());
                fpHasImage = test.ok;
                if (fpHasImage) {
                    img.src = '/api/floorplan?_=' + Date.now();
                }
            }

            document.getElementById('fpUploadArea').style.display = fpHasImage ? 'none' : 'flex';
            document.getElementById('fpImageArea').style.display = fpHasImage ? 'block' : 'none';
            document.getElementById('fpEditBtn').style.display = fpHasImage ? 'inline-block' : 'none';
            document.getElementById('fpUploadLabel').style.display = fpHasImage && fpEditMode ? 'inline-block' : 'none';

            if (fpHasImage) {
                renderFpPins();
                renderFpUnplaced();
            }
        }

        function renderFpPins() {
            const layer = document.getElementById('fpPinsLayer');
            const wrap = document.getElementById('fpImageWrap');
            layer.innerHTML = '';

            wrap.classList.toggle('view-mode', !fpEditMode);
            wrap.style.cursor = (fpEditMode && fpSelectedSensor && !fpPositions[fpSelectedSensor])
                ? 'crosshair' : (fpEditMode ? 'default' : 'default');

            allSensors.forEach(name => {
                const pos = fpPositions[name];
                if (!pos) return;

                const color = sensorColorMap[name] || '#4A9EFF';
                const r = latestReadings[name] || {};

                const pin = document.createElement('div');
                pin.className = 'fp-pin' + (fpEditMode ? ' edit-mode' : '') +
                    (fpSelectedSensor === name ? ' selected' : '');
                pin.style.left = (pos.x * 100) + '%';
                pin.style.top = (pos.y * 100) + '%';
                pin.dataset.sensor = name;

                const label = document.createElement('div');
                label.className = 'fp-pin-label';
                label.style.borderLeftColor = color;

                const nameSpan = document.createElement('span');
                nameSpan.className = 'fp-pin-name';
                nameSpan.textContent = name;

                const readings = document.createElement('div');
                readings.className = 'fp-pin-readings';
                if (r.temp != null) {
                    const t = document.createElement('span');
                    t.className = 'fp-pin-temp';
                    t.textContent = r.temp.toFixed(1) + '°';
                    readings.appendChild(t);
                }
                if (r.hum != null) {
                    const h = document.createElement('span');
                    h.className = 'fp-pin-hum';
                    h.textContent = r.hum.toFixed(0) + '%';
                    readings.appendChild(h);
                }

                label.appendChild(nameSpan);
                label.appendChild(readings);
                pin.appendChild(label);

                if (fpEditMode) {
                    const removeBtn = document.createElement('button');
                    removeBtn.className = 'fp-pin-remove';
                    removeBtn.title = 'Remove from map';
                    removeBtn.textContent = '×';
                    removeBtn.addEventListener('pointerdown', e => e.stopPropagation());
                    removeBtn.addEventListener('click', e => {
                        e.stopPropagation();
                        delete fpPositions[name];
                        savePositions();
                        fpSelectedSensor = null;
                        renderFpPins();
                        renderFpUnplaced();
                    });
                    pin.appendChild(removeBtn);

                    makePinDraggable(pin, name);
                }

                layer.appendChild(pin);
            });

            // Click on image wrap to place selected unplaced sensor
            const existingHandler = wrap._fpClickHandler;
            if (existingHandler) wrap.removeEventListener('click', existingHandler);
            wrap._fpClickHandler = (e) => {
                if (!fpEditMode) return;
                if (!fpSelectedSensor) return;
                if (fpPositions[fpSelectedSensor]) return;  // already placed
                if (e.target.closest('.fp-pin')) return;    // clicked a pin

                const rect = wrap.getBoundingClientRect();
                const img = document.getElementById('fpImage');
                // Pins layer covers the image area
                const x = (e.clientX - rect.left) / rect.width;
                const y = (e.clientY - rect.top) / rect.height;
                fpPositions[fpSelectedSensor] = { x, y };
                fpSelectedSensor = null;
                savePositions();
                renderFpPins();
                renderFpUnplaced();
            };
            wrap.addEventListener('click', wrap._fpClickHandler);
        }

        function makePinDraggable(pinEl, sensorName) {
            let dragging = false;
            let startX, startY, startPosX, startPosY;

            pinEl.addEventListener('pointerdown', e => {
                if (e.target.classList.contains('fp-pin-remove')) return;
                e.preventDefault();
                dragging = false;
                startX = e.clientX;
                startY = e.clientY;
                startPosX = fpPositions[sensorName]?.x ?? 0.5;
                startPosY = fpPositions[sensorName]?.y ?? 0.5;
                fpSelectedSensor = sensorName;
                pinEl.setPointerCapture(e.pointerId);
                renderFpUnplaced();  // update chip highlight
            });

            pinEl.addEventListener('pointermove', e => {
                if (!pinEl.hasPointerCapture(e.pointerId)) return;
                const dx = e.clientX - startX;
                const dy = e.clientY - startY;
                if (!dragging && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                    dragging = true;
                    pinEl.classList.add('dragging');
                }
                if (!dragging) return;
                const wrap = document.getElementById('fpImageWrap');
                const rect = wrap.getBoundingClientRect();
                const newX = Math.max(0, Math.min(1, startPosX + dx / rect.width));
                const newY = Math.max(0, Math.min(1, startPosY + dy / rect.height));
                fpPositions[sensorName] = { x: newX, y: newY };
                pinEl.style.left = (newX * 100) + '%';
                pinEl.style.top = (newY * 100) + '%';
            });

            pinEl.addEventListener('pointerup', e => {
                pinEl.classList.remove('dragging');
                if (dragging) {
                    savePositions();
                }
                dragging = false;
            });
        }

        function renderFpUnplaced() {
            const panel = document.getElementById('fpUnplacedPanel');
            const chips = document.getElementById('fpUnplacedChips');

            if (!fpEditMode) { panel.style.display = 'none'; return; }

            const unplaced = allSensors.filter(n => !fpPositions[n]);
            panel.style.display = unplaced.length > 0 ? 'block' : 'none';

            chips.innerHTML = '';
            unplaced.forEach(name => {
                const color = sensorColorMap[name] || '#4A9EFF';
                const chip = document.createElement('div');
                chip.className = 'fp-chip' + (fpSelectedSensor === name ? ' selected' : '');
                chip.innerHTML = `<span class="fp-chip-dot" style="background:${color}"></span>${name}`;
                chip.onclick = () => {
                    fpSelectedSensor = fpSelectedSensor === name ? null : name;
                    renderFpUnplaced();
                    renderFpPins();
                };
                chips.appendChild(chip);
            });

            // Update cursor hint
            let hint = panel.querySelector('.fp-hint');
            if (!hint) {
                hint = document.createElement('div');
                hint.className = 'fp-hint';
                panel.appendChild(hint);
            }
            if (fpSelectedSensor && !fpPositions[fpSelectedSensor]) {
                hint.textContent = `Click on the floor plan to place "${fpSelectedSensor}"`;
                hint.style.display = 'block';
            } else {
                hint.style.display = 'none';
            }
        }

        function toggleFpEdit() {
            fpEditMode = !fpEditMode;
            const btn = document.getElementById('fpEditBtn');
            const uploadLabel = document.getElementById('fpUploadLabel');
            btn.textContent = fpEditMode ? 'Done' : 'Edit Layout';
            btn.classList.toggle('primary', !fpEditMode);
            uploadLabel.style.display = fpHasImage && fpEditMode ? 'inline-block' : 'none';
            if (!fpEditMode) fpSelectedSensor = null;
            renderFpPins();
            renderFpUnplaced();
        }

        async function handleFloorPlanUpload(event) {
            const file = event.target.files[0];
            if (!file) return;
            event.target.value = '';  // reset so same file can be re-selected

            try {
                const resp = await fetch('/api/floorplan', {
                    method: 'POST',
                    headers: { 'Content-Type': file.type || 'image/jpeg' },
                    body: file
                });
                if (!resp.ok) throw new Error('Upload failed');
                fpHasImage = true;
                const img = document.getElementById('fpImage');
                img.src = '/api/floorplan?_=' + Date.now();
                document.getElementById('fpUploadArea').style.display = 'none';
                document.getElementById('fpImageArea').style.display = 'block';
                document.getElementById('fpEditBtn').style.display = 'inline-block';
                document.getElementById('fpUploadLabel').style.display = fpEditMode ? 'inline-block' : 'none';
                renderFpPins();
                renderFpUnplaced();
            } catch (e) {
                alert('Failed to upload floor plan: ' + e.message);
            }
        }

        async function savePositions() {
            try {
                await fetch('/api/floorplan/positions', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(fpPositions)
                });
            } catch (e) {
                console.error('Failed to save positions:', e);
            }
        }

        // Drag-and-drop onto upload area
        const uploadArea = document.getElementById('fpUploadArea');
        uploadArea.addEventListener('dragover', e => { e.preventDefault(); uploadArea.classList.add('drag-over'); });
        uploadArea.addEventListener('dragleave', () => uploadArea.classList.remove('drag-over'));
        uploadArea.addEventListener('drop', async e => {
            e.preventDefault();
            uploadArea.classList.remove('drag-over');
            const file = e.dataTransfer.files[0];
            if (file && file.type.startsWith('image/')) {
                await handleFloorPlanUpload({ target: { files: [file], value: '' } });
            }
        });

        // ── Init ─────────────────────────────────────────────────────
        (async () => {
            await loadSensors();
            // Load floor plan positions early
            try {
                const r = await fetch('/api/floorplan/positions');
                fpPositions = await r.json();
            } catch (e) { fpPositions = {}; }
            await loadData();
            renderFloorPlan();
            setInterval(loadData, 60000);
        })();
        </script>
    </body>
    </html>
    """
}
