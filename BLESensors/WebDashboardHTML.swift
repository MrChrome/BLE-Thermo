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
            :root {
                --bg: #111213;
                --surface: #18191b;
                --surface-2: #202124;
                --surface-3: #2a2b2f;
                --line: #2b2c30;
                --line-soft: #222326;
                --text: #e9e7e3;
                --text-2: #a8a5a0;
                --text-3: #6e6c68;
                --accent: #e3a33b;
                --accent-dim: rgba(227,163,59,0.14);
                --warm: #e5835f;
                --cool: #6aa6d8;
                --danger: #e8604c;
                --good: #7fb685;
                --radius: 6px;
            }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
                font-size: 14px;
                background: var(--bg);
                color: var(--text);
                min-height: 100vh;
                padding: 28px 24px;
                -webkit-font-smoothing: antialiased;
            }
            .container { max-width: 960px; margin: 0 auto; }
            h1 {
                font-size: 1.25rem;
                font-weight: 600;
                letter-spacing: -0.01em;
                margin-bottom: 18px;
                color: var(--text);
                cursor: pointer;
                display: inline-block;
            }
            h1:hover { color: var(--text-2); }
            h1[contenteditable="true"] {
                outline: none;
                border-bottom: 1px solid var(--accent);
                cursor: text;
                padding-bottom: 2px;
                color: var(--text);
            }
            /* Tab bar */
            .tab-bar {
                display: flex;
                gap: 24px;
                margin-bottom: 20px;
                border-bottom: 1px solid var(--line);
            }
            .tab-btn {
                padding: 0 0 10px;
                border: none;
                border-bottom: 2px solid transparent;
                background: none;
                color: var(--text-3);
                font: inherit;
                font-weight: 500;
                cursor: pointer;
                margin-bottom: -1px;
            }
            .tab-btn:hover { color: var(--text-2); }
            .tab-btn.active { color: var(--text); border-bottom-color: var(--accent); }
            .tab-content { display: none; }
            .tab-content.active { display: block; }
            /* Charts tab: segmented controls */
            .range-picker, .metric-toggle {
                display: inline-flex;
                flex-wrap: wrap;
                background: var(--surface);
                border: 1px solid var(--line);
                border-radius: var(--radius);
                padding: 2px;
                gap: 2px;
            }
            .range-btn, .metric-toggle-btn {
                padding: 5px 11px;
                border: none;
                border-radius: 4px;
                background: none;
                color: var(--text-2);
                font: inherit;
                font-size: 13px;
                cursor: pointer;
                white-space: nowrap;
            }
            .range-btn:hover, .metric-toggle-btn:hover { color: var(--text); }
            .range-btn.active, .metric-toggle-btn.active {
                background: #333438;
                color: var(--text);
            }
            .metric-toggle { flex-shrink: 0; }
            .metric-toggle-btn { padding: 3px 9px; font-size: 12px; font-weight: 400; }
            .controls-row {
                display: flex;
                gap: 8px;
                align-items: flex-start;
                margin-bottom: 16px;
                flex-wrap: wrap;
            }
            .sensor-select {
                height: 33px;
                padding: 0 30px 0 12px;
                border: 1px solid var(--line);
                border-radius: var(--radius);
                background-color: var(--surface);
                color: var(--text);
                font: inherit;
                font-size: 13px;
                cursor: pointer;
                appearance: none;
                -webkit-appearance: none;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 10 10'%3E%3Cpath d='M2 3.5l3 3 3-3' fill='none' stroke='%23a8a5a0' stroke-width='1.4'/%3E%3C/svg%3E");
                background-repeat: no-repeat;
                background-position: right 11px center;
                flex-shrink: 0;
            }
            .sensor-select:hover { border-color: var(--surface-3); }
            .sensor-select:focus { outline: none; border-color: var(--accent); }
            .sensor-select option { background: var(--surface); color: var(--text); }
            .fav-btn {
                height: 33px;
                width: 33px;
                border: 1px solid var(--line);
                border-radius: var(--radius);
                background: var(--surface);
                color: var(--text-3);
                font-size: 15px;
                cursor: pointer;
                flex-shrink: 0;
                line-height: 1;
            }
            .fav-btn:hover { color: var(--text-2); }
            .fav-btn.active { color: var(--accent); border-color: rgba(227,163,59,0.4); }
            .chart-card {
                background: var(--surface);
                border: 1px solid var(--line);
                border-radius: var(--radius);
                padding: 16px 18px 12px;
                margin-bottom: 12px;
            }
            .chart-card h2 {
                font-size: 13px;
                font-weight: 600;
                margin-bottom: 14px;
                color: var(--text);
            }
            .chart-wrap { position: relative; height: 260px; }
            .loading {
                text-align: center;
                padding: 40px;
                color: var(--text-3);
            }
            .main-layout {
                display: flex;
                gap: 12px;
                align-items: flex-start;
            }
            .charts-col { flex: 1; min-width: 0; }
            .side-col {
                display: none;
                width: 230px;
                flex-shrink: 0;
                position: sticky;
                top: 24px;
                flex-direction: column;
                gap: 12px;
            }
            /* Low battery banner */
            .battery-alert {
                display: none;
                align-items: center;
                gap: 16px;
                margin-bottom: 20px;
                padding: 16px 20px;
                border-radius: var(--radius);
                border: 1px solid rgba(232,96,76,0.35);
                border-left: 4px solid var(--danger);
                background: #211614;
            }
            .battery-alert svg { width: 40px; height: 40px; flex-shrink: 0; color: var(--danger); }
            .battery-alert-title {
                font-size: 1.5rem;
                font-weight: 600;
                letter-spacing: -0.01em;
                color: #f3c2b9;
                line-height: 1.15;
            }
            .battery-alert-list {
                margin-top: 4px;
                color: var(--text-2);
                font-variant-numeric: tabular-nums;
            }
            @media (max-width: 560px) {
                .battery-alert { gap: 12px; padding: 12px 14px; }
                .battery-alert svg { width: 32px; height: 32px; }
                .battery-alert-title { font-size: 1.2rem; }
            }
            /* Single-sensor trend banner */
            .sensor-trend {
                display: none;
                align-items: center;
                gap: 16px;
                margin-bottom: 12px;
                padding: 14px 20px;
                background: var(--surface);
                border: 1px solid var(--line);
                border-left: 4px solid var(--st-color);
                border-radius: var(--radius);
                font-variant-numeric: tabular-nums;
            }
            .sensor-trend.rising  { --st-color: var(--warm); }
            .sensor-trend.falling { --st-color: var(--cool); }
            .st-arrow { width: 36px; height: 36px; flex-shrink: 0; color: var(--st-color); }
            .st-arrow svg { display: block; width: 100%; height: 100%; }
            .sensor-trend.rising  .st-arrow { transform: rotate(-45deg); }
            .sensor-trend.falling .st-arrow { transform: rotate(45deg); }
            .st-main { flex: 1; min-width: 0; }
            .st-label {
                font-size: 1.5rem;
                font-weight: 600;
                letter-spacing: -0.01em;
                color: var(--st-color);
                line-height: 1.15;
            }
            .st-sub { margin-top: 3px; font-size: 13px; color: var(--text-2); }
            .st-temp {
                font-size: 2rem;
                font-weight: 600;
                color: var(--text);
                line-height: 1;
                white-space: nowrap;
                text-align: right;
            }
            .st-hum { display: block; margin-top: 4px; font-size: 12px; font-weight: 400; color: var(--text-3); }
            @media (max-width: 560px) {
                .sensor-trend { gap: 12px; padding: 12px 14px; }
                .st-arrow { width: 28px; height: 28px; }
                .st-label { font-size: 1.2rem; }
                .st-temp { font-size: 1.5rem; }
            }
            /* Side panels */
            .current-panel, .dewpoint-panel {
                background: var(--surface);
                border: 1px solid var(--line);
                border-radius: var(--radius);
                padding: 12px 14px 6px;
            }
            .current-panel h2, .dewpoint-panel h2 {
                font-size: 13px;
                font-weight: 600;
                color: var(--text);
                padding-bottom: 8px;
                border-bottom: 1px solid var(--line);
            }
            .current-sensor-row, .dp-row {
                display: flex;
                align-items: baseline;
                justify-content: space-between;
                padding: 7px 0;
                border-bottom: 1px solid var(--line-soft);
                gap: 8px;
                font-variant-numeric: tabular-nums;
            }
            .current-sensor-row:last-child, .dp-row:last-child { border-bottom: none; }
            .current-sensor-row {
                cursor: pointer;
                margin: 0 -14px;
                padding-left: 14px;
                padding-right: 14px;
            }
            .current-sensor-row:hover { background: var(--surface-2); }
            .current-sensor-row:hover .current-sensor-name { color: var(--text); }
            .current-sensor-name, .dp-label {
                font-size: 13px;
                color: var(--text-2);
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                flex: 1;
            }
            .current-sensor-temp, .dp-value {
                font-size: 14px;
                font-weight: 600;
                color: var(--text);
                white-space: nowrap;
            }
            .trend-arrow {
                display: inline-block;
                width: 0.75em;
                height: 0.75em;
                margin-right: 5px;
                vertical-align: -0.02em;
            }
            .trend-arrow svg { display: block; width: 100%; height: 100%; }
            .trend-arrow.up   { color: var(--warm); transform: rotate(-45deg); }
            .trend-arrow.flat { color: var(--text-3); }
            .trend-arrow.down { color: var(--cool); transform: rotate(45deg); }
            .current-sensor-hum {
                font-size: 12px;
                color: var(--text-3);
                white-space: nowrap;
            }
            .current-dot {
                width: 3px;
                height: 12px;
                border-radius: 1px;
                flex-shrink: 0;
                align-self: center;
            }
            .dp-outside:not(:empty) { border-top: 1px solid var(--line-soft); }
            .dp-delta {
                font-size: 12px;
                white-space: nowrap;
            }
            .dp-delta.drier { color: var(--danger); }
            .dp-delta.wetter { color: var(--good); }
            @media (min-width: 900px) {
                .container { max-width: 1160px; }
                .side-col { display: flex; }
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
                padding: 6px 14px;
                border: 1px solid var(--line);
                border-radius: var(--radius);
                background: var(--surface);
                color: var(--text-2);
                font: inherit;
                font-size: 13px;
                cursor: pointer;
                white-space: nowrap;
            }
            .fp-btn:hover { color: var(--text); border-color: var(--surface-3); }
            .fp-btn.primary { color: var(--text); }
            .fp-btn.primary:hover { border-color: var(--accent); }
            .fp-btn.danger {
                border-color: rgba(232,96,76,0.35);
                color: var(--danger);
            }
            .fp-upload-area {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 10px;
                min-height: 300px;
                border: 1px dashed var(--surface-3);
                border-radius: var(--radius);
                color: var(--text-3);
                cursor: pointer;
            }
            .fp-upload-area:hover, .fp-upload-area.drag-over {
                border-color: var(--accent);
                color: var(--text-2);
            }
            .fp-upload-icon { width: 40px; height: 40px; color: var(--text-3); }
            /* Image area */
            .fp-image-area { position: relative; }
            .fp-image-wrap {
                position: relative;
                display: inline-block;
                max-width: 100%;
                border-radius: var(--radius);
                overflow: hidden;
                background: var(--surface);
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
                background: rgba(17,18,19,0.94);
                border: 1px solid #000;
                border-left-width: 3px;
                border-radius: 4px;
                padding: 3px 8px 4px;
                white-space: nowrap;
                line-height: 1.35;
                text-align: left;
                pointer-events: none;
                box-shadow: 0 1px 3px rgba(0,0,0,0.35);
                font-variant-numeric: tabular-nums;
            }
            .fp-pin-name {
                display: block;
                color: var(--text-2);
                font-size: 10px;
            }
            .fp-pin-readings {
                display: flex;
                gap: 6px;
                align-items: baseline;
            }
            .fp-pin-temp { color: var(--text); font-weight: 600; font-size: 13px; }
            .fp-pin-hum { color: var(--text-3); font-size: 10px; }
            .fp-pin-remove {
                position: absolute;
                top: -6px;
                right: -20px;
                width: 18px; height: 18px;
                border-radius: 50%;
                background: var(--danger);
                border: none;
                color: #fff;
                font-size: 13px;
                font-weight: 600;
                cursor: pointer;
                line-height: 1;
                display: flex; align-items: center; justify-content: center;
                pointer-events: all;
            }
            .fp-pin.edit-mode { cursor: grab; }
            .fp-pin.edit-mode:active { cursor: grabbing; }
            .fp-pin.selected .fp-pin-label {
                box-shadow: 0 0 0 2px var(--accent);
            }
            /* Unplaced sensors panel */
            .fp-unplaced-panel {
                margin-top: 12px;
                background: var(--surface);
                border: 1px solid var(--line);
                border-radius: var(--radius);
                padding: 12px 14px;
            }
            .fp-unplaced-label {
                font-size: 13px;
                color: var(--text-2);
                margin-bottom: 10px;
            }
            .fp-unplaced-chips { display: flex; flex-wrap: wrap; gap: 6px; }
            .fp-chip {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 4px 10px;
                border-radius: 4px;
                border: 1px solid var(--line);
                background: var(--surface-2);
                cursor: pointer;
                font-size: 12px;
                color: var(--text-2);
            }
            .fp-chip:hover { color: var(--text); border-color: var(--surface-3); }
            .fp-chip.selected {
                border-color: var(--accent);
                background: var(--accent-dim);
                color: var(--text);
            }
            .fp-chip-dot {
                width: 3px; height: 11px;
                border-radius: 1px;
                flex-shrink: 0;
            }
            .fp-hint {
                margin-top: 10px;
                font-size: 12px;
                color: var(--text-3);
            }
            .muted-note { font-size: 12px; color: var(--text-3); padding: 7px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1 id="pageTitle" title="Click to rename"></h1>

            <div class="battery-alert" id="batteryAlert">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="17" height="10" rx="2"/><path d="M22 11v2"/><path d="M6 10v4"/></svg>
                <div>
                    <div class="battery-alert-title" id="batteryAlertTitle"></div>
                    <div class="battery-alert-list" id="batteryAlertList"></div>
                </div>
            </div>

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
                <div class="sensor-trend" id="sensorTrend">
                    <span class="st-arrow" id="stArrow"></span>
                    <div class="st-main">
                        <div class="st-label" id="stLabel"></div>
                        <div class="st-sub" id="stSub"></div>
                    </div>
                    <div class="st-temp"><span id="stTemp"></span><span class="st-hum" id="stHum"></span></div>
                </div>
                <div class="main-layout">
                    <div class="charts-col">
                        <div class="chart-card">
                            <h2>Temperature &deg;F</h2>
                            <div class="chart-wrap"><canvas id="tempChart"></canvas></div>
                        </div>
                        <div class="chart-card">
                            <h2 style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
                                <span id="humChartLabel">Humidity %</span>
                                <div class="metric-toggle">
                                    <button class="metric-toggle-btn active" id="btnRH" onclick="setHumMode('rh')">RH %</button>
                                    <button class="metric-toggle-btn" id="btnDP" onclick="setHumMode('dp')">Dew Point</button>
                                </div>
                            </h2>
                            <div class="chart-wrap"><canvas id="humChart"></canvas></div>
                        </div>
                    </div>
                    <div class="side-col">
                        <div class="current-panel" id="currentPanel">
                            <h2>Current</h2>
                            <div id="currentReadings"></div>
                            <div class="dp-outside" id="currentOutside"></div>
                        </div>
                        <div class="dewpoint-panel" id="dewpointPanel">
                            <h2>Dew point</h2>
                            <div id="dewpointReadings"></div>
                            <div class="dp-outside" id="dewpointOutside"></div>
                        </div>
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
                <div class="main-layout">
                    <div class="charts-col" id="fpContent">
                        <!-- Upload area (shown when no image) -->
                        <label class="fp-upload-area" id="fpUploadArea" for="fpFileInputMain">
                            <svg class="fp-upload-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10.5L12 3l9 7.5"/><path d="M5 9v12h14V9"/><path d="M10 21v-6h4v6"/></svg>
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
                                <div class="fp-unplaced-label">Unplaced sensors: pick one, then click the map to place it</div>
                                <div class="fp-unplaced-chips" id="fpUnplacedChips"></div>
                            </div>
                        </div>
                    </div>
                    <div class="side-col">
                        <div class="current-panel">
                            <h2>Current</h2>
                            <div id="fpCurrentReadings"></div>
                            <div class="dp-outside" id="fpCurrentOutside"></div>
                        </div>
                        <div class="dewpoint-panel">
                            <h2>Dew point</h2>
                            <div id="fpDewpointReadings"></div>
                            <div class="dp-outside" id="fpDewpointOutside"></div>
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
            '#e3a33b','#6aa6d8','#7fb685','#d9776b','#b294bb',
            '#5fb3b3','#cfc6b4','#8f9bb3','#e58fa8','#a3c46b'
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
        let showDewPoint = localStorage.getItem('bleShowDP') === 'true';

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

        // Clicking a room in a Current panel jumps to its graph on the Charts tab.
        function showSensorGraph(name) {
            switchTab('charts');
            sensorSelect.value = name;
            currentSensor = name;
            updateFavBtn();
            window.scrollTo({ top: 0, behavior: 'smooth' });
            loadData();
        }
        ['currentReadings', 'fpCurrentReadings'].forEach(id => {
            document.getElementById(id).addEventListener('click', e => {
                const row = e.target.closest('.current-sensor-row');
                if (row) showSensorGraph(row.dataset.sensor);
            });
        });

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

        function setHumMode(mode) {
            showDewPoint = mode === 'dp';
            localStorage.setItem('bleShowDP', showDewPoint);
            document.getElementById('btnRH').classList.toggle('active', !showDewPoint);
            document.getElementById('btnDP').classList.toggle('active', showDewPoint);
            document.getElementById('humChartLabel').textContent = showDewPoint ? 'Dew point \\u00B0F' : 'Humidity %';
            loadData();
        }

        function applyHumModeUI() {
            document.getElementById('btnRH').classList.toggle('active', !showDewPoint);
            document.getElementById('btnDP').classList.toggle('active', showDewPoint);
            document.getElementById('humChartLabel').textContent = showDewPoint ? 'Dew point \\u00B0F' : 'Humidity %';
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
                    borderColor: sensorColorMap[name] || COLORS[0],
                    backgroundColor: (sensorColorMap[name] || COLORS[0]) + '18',
                    tension: 0.2,
                    pointRadius: 0,
                    borderWidth: 1.5,
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
                    borderColor: 'rgba(255,255,255,0.18)',
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

        Chart.defaults.font.family = getComputedStyle(document.body).fontFamily;
        Chart.defaults.font.size = 11;

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
                            labels: { color: '#a8a5a0', boxWidth: 14, boxHeight: 2, padding: 14 },
                            onClick: legendClickHandler
                        },
                        tooltip: {
                            mode: 'index',
                            intersect: false,
                            backgroundColor: '#202124',
                            titleColor: '#a8a5a0',
                            bodyColor: '#e9e7e3',
                            borderColor: '#2b2c30',
                            borderWidth: 1,
                            cornerRadius: 4,
                            boxWidth: 8,
                            boxHeight: 8,
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
                            ticks: { color: '#6e6c68', maxTicksLimit: 8 },
                            grid: { color: 'rgba(255,255,255,0.04)' },
                            border: { color: '#2b2c30' }
                        },
                        y: {
                            ticks: { color: '#6e6c68' },
                            grid: { color: 'rgba(255,255,255,0.04)' },
                            border: { display: false }
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
                const url = '/api/data?range=' + currentRange;
                const showingFavorites = currentSensor === '__favorites__';
                const resp = await fetch(url);
                const data = await resp.json();
                const allData = data;
                const unit = timeUnit(currentRange);

                let tempData = data.temperature;
                let humData = data.humidity;
                if (showingFavorites) {
                    tempData = Object.fromEntries(Object.entries(tempData).filter(([k]) => favorites.has(k)));
                    humData = Object.fromEntries(Object.entries(humData).filter(([k]) => favorites.has(k)));
                } else if (currentSensor) {
                    tempData = Object.fromEntries(Object.entries(tempData).filter(([k]) => k === currentSensor));
                    humData = Object.fromEntries(Object.entries(humData).filter(([k]) => k === currentSensor));
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
                let secondaryData = humData;
                if (showDewPoint) {
                    secondaryData = {};
                    Object.keys(humData).forEach(name => {
                        const tPts = tempData[name];
                        const hPts = humData[name];
                        if (tPts && hPts) secondaryData[name] = computeDewPointSeries(tPts, hPts);
                    });
                }
                const humDS = buildDatasets(secondaryData);

                if (!tempChart) {
                    tempChart = makeChart(document.getElementById('tempChart'), tempDS, unit);
                    humChart = makeChart(document.getElementById('humChart'), humDS, unit);
                } else {
                    updateChart(tempChart, tempDS, unit);
                    updateChart(humChart, humDS, unit);
                }
                // Coarse ranges lack per-minute rows, so fetch the last hour for trend arrows.
                const hourData = FINE_RANGES.indexOf(currentRange) !== -1 ? data : await fetchHourData();
                renderCurrentReadings(data.temperature, data.humidity, hourData && hourData.temperature);
                renderSensorTrend(hourData);
                renderDewPointPanel(allData.temperature, allData.humidity);
                await loadBatteryAlert();

                // Refresh floor plan pins if visible
                if (document.getElementById('tab-floorplan').classList.contains('active')) {
                    renderFpPins();
                }
            } catch (e) {
                console.error('Failed to load data:', e);
            }
        }

        // ── Trend arrows ─────────────────────────────────
        // Ranges that return raw 60-second rows, so a short trailing window is meaningful.
        const FINE_RANGES = ['hour', '6h', 'today', 'day'];
        const TREND_WINDOW_SEC = 60 * 60;
        const BANNER_WINDOW_SEC = 30 * 60; // single-sensor banner reacts faster than the arrows
        const TREND_STEADY_RATE = 0.5;   // °F/hr below which we call it steady
        const TREND_FAST_RATE = 2.0;     // °F/hr above which we call it fast
        const TREND_STALE_SEC = 20 * 60; // readings older than this can't describe "now"

        function isStale(points) {
            if (!points || points.length === 0) return true;
            return (Date.now() / 1000) - points[points.length - 1].t > TREND_STALE_SEC;
        }

        // Least-squares slope over the trailing window, in °F per hour.
        function trendOf(points, windowSec = TREND_WINDOW_SEC) {
            if (!points || points.length < 2) return null;
            const lastT = points[points.length - 1].t;
            let win = points.filter(p => lastT - p.t <= windowSec);
            if (win.length < 3) win = points.slice(-3);
            if (win.length < 2) return null;
            const t0 = win[0].t;
            const n = win.length;
            let sx = 0, sy = 0, sxx = 0, sxy = 0;
            win.forEach(p => {
                const x = (p.t - t0) / 3600;
                sx += x; sy += p.v; sxx += x * x; sxy += x * p.v;
            });
            const denom = n * sxx - sx * sx;
            if (denom === 0) return null;
            const rate = (n * sxy - sx * sy) / denom;
            const spanHours = (win[win.length - 1].t - t0) / 3600;
            return {
                rate: rate,
                change: rate * spanHours,
                spanMin: spanHours * 60,
                value: win[win.length - 1].v
            };
        }

        // Called sequentially from loadData — the server serializes /api/data,
        // so never overlap these requests.
        async function fetchHourData() {
            try {
                const resp = await fetch('/api/data?range=hour');
                return await resp.json();
            } catch (e) {
                return null;
            }
        }

        const TREND_ARROW_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h17M13 5l7 7-7 7"/></svg>';

        // Up / flat / down arrow from the slope over the past hour; empty if there's no recent data.
        function hourTrendArrow(points) {
            if (!points || isStale(points)) return '';
            const tr = trendOf(points);
            if (!tr) return '';
            const dir = Math.abs(tr.rate) < TREND_STEADY_RATE ? 'flat' : (tr.rate > 0 ? 'up' : 'down');
            const title = (tr.change >= 0 ? '+' : '−') + Math.abs(tr.change).toFixed(1) +
                '° over the last ' + Math.max(1, Math.round(tr.spanMin)) + ' min';
            return `<span class="trend-arrow ${dir}" title="${title}">${TREND_ARROW_SVG}</span>`;
        }

        // Rising / falling banner, shown only when one sensor is selected and it isn't holding steady.
        function renderSensorTrend(hourData) {
            const card = document.getElementById('sensorTrend');
            const name = currentSensor && currentSensor !== '__favorites__' ? currentSensor : null;
            const tempPts = name && hourData && hourData.temperature ? hourData.temperature[name] : null;
            const tr = trendOf(tempPts, BANNER_WINDOW_SEC);
            if (!tr || isStale(tempPts)) { card.style.display = 'none'; return; }

            const mag = Math.abs(tr.rate);
            if (mag < TREND_STEADY_RATE) { card.style.display = 'none'; return; }
            const fast = mag >= TREND_FAST_RATE;
            let cls, label;
            if (tr.rate > 0) {
                cls = 'rising';  label = fast ? 'Rising Fast' : 'Rising';
            } else {
                cls = 'falling'; label = fast ? 'Falling Fast' : 'Falling';
            }
            card.className = 'sensor-trend ' + cls;
            card.style.display = 'flex';
            document.getElementById('stArrow').innerHTML = TREND_ARROW_SVG;
            document.getElementById('stLabel').textContent = name + ' ' + label;

            const sign = tr.rate > 0 ? '+' : '−';
            document.getElementById('stSub').textContent =
                sign + mag.toFixed(1) + '°F/hr · ' + sign + Math.abs(tr.change).toFixed(1) +
                '° over the last ' + Math.max(1, Math.round(tr.spanMin)) + ' min';

            document.getElementById('stTemp').textContent = tr.value.toFixed(1) + '°';
            const humPts = hourData.humidity ? hourData.humidity[name] : null;
            document.getElementById('stHum').textContent =
                humPts && humPts.length ? humPts[humPts.length - 1].v.toFixed(0) + '% RH' : '';
        }

        function renderCurrentReadings(tempData, humData, hourTempData) {
            const rows = allSensors
                .map(name => {
                    const tPts = tempData[name];
                    const hPts = humData[name];
                    const temp = tPts && tPts.length > 0 ? tPts[tPts.length - 1].v : null;
                    const hum  = hPts && hPts.length > 0 ? hPts[hPts.length - 1].v : null;
                    const arrow = hourTrendArrow(hourTempData && hourTempData[name]);
                    return { name, temp, hum, arrow };
                })
                .filter(r => r.temp !== null)
                .sort((a, b) => b.temp - a.temp);

            const html = rows.map(r => {
                const color = sensorColorMap[r.name] || COLORS[0];
                const humStr = r.hum !== null ? r.hum.toFixed(0) + '%' : '';
                const attrName = r.name.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
                return `<div class="current-sensor-row" data-sensor="${attrName}" title="Show ${attrName} graph">
                    <span class="current-dot" style="background:${color}"></span>
                    <span class="current-sensor-name" title="${r.name}">${r.name}</span>
                    <span class="current-sensor-hum">${humStr}</span>
                    <span class="current-sensor-temp">${r.arrow}${r.temp.toFixed(1)}&deg;</span>
                </div>`;
            }).join('');

            const c1 = document.getElementById('currentReadings');
            if (c1) c1.innerHTML = html;
            const c2 = document.getElementById('fpCurrentReadings');
            if (c2) c2.innerHTML = html;
        }

        // ── Low battery alert ─────────────────────────────
        const LOW_BATTERY_PCT = 15; // matches the HomeKit low-battery threshold

        async function loadBatteryAlert() {
            const card = document.getElementById('batteryAlert');
            try {
                const resp = await fetch('/api/battery');
                const j = await resp.json();
                const low = j.sensors
                    .filter(s => s.battery < LOW_BATTERY_PCT)
                    .sort((a, b) => a.battery - b.battery);
                if (low.length === 0) { card.style.display = 'none'; return; }
                document.getElementById('batteryAlertTitle').textContent =
                    low.length === 1 ? 'Replace Battery' : 'Replace ' + low.length + ' Batteries';
                document.getElementById('batteryAlertList').textContent =
                    low.map(s => s.name + ' (' + s.battery + '%)').join(' · ');
                card.style.display = 'flex';
            } catch (e) {
                console.error('Failed to load battery levels:', e);
            }
        }

        // ── Outside weather ───────────────────────────────
        // Open-Meteo (free, no key) for conditions; location from the browser's
        // public IP via ipwho.is, cached for a day.
        const OUTSIDE_REFRESH_MS = 10 * 60 * 1000;
        const LOCATION_CACHE_MS = 24 * 60 * 60 * 1000;

        async function outsideLocation() {
            try {
                const cached = JSON.parse(localStorage.getItem('bleOutsideLoc') || 'null');
                if (cached && Date.now() - cached.at < LOCATION_CACHE_MS) return cached;
            } catch (e) { /* refetch */ }
            const resp = await fetch('https://ipwho.is/');
            const j = await resp.json();
            if (typeof j.latitude !== 'number') throw new Error('No location');
            const loc = { lat: j.latitude, lon: j.longitude, at: Date.now() };
            try { localStorage.setItem('bleOutsideLoc', JSON.stringify(loc)); } catch (e) {}
            return loc;
        }

        async function loadOutside() {
            let html, dpHtml = '';
            try {
                const loc = await outsideLocation();
                const url = 'https://api.open-meteo.com/v1/forecast?latitude=' + loc.lat + '&longitude=' + loc.lon +
                    '&current=temperature_2m,relative_humidity_2m,dew_point_2m' +
                    '&temperature_unit=fahrenheit';
                const w = await (await fetch(url)).json();
                const c = w.current;
                const row = (label, value) => `<div class="dp-row">
                    <span class="dp-label">${label}</span>
                    <span class="dp-value">${value}</span>
                </div>`;
                // Spacer keeps "Outside" aligned with the room names beside their color bars.
                html = `<div class="dp-row">
                    <span class="current-dot"></span>
                    <span class="dp-label">Outside</span>
                    <span class="current-sensor-hum">${c.relative_humidity_2m.toFixed(0)}%</span>
                    <span class="dp-value">${c.temperature_2m.toFixed(1)}&deg;</span>
                </div>`;
                dpHtml = row('Outside', c.dew_point_2m.toFixed(1) + '&deg;');
            } catch (e) {
                console.error('Failed to load outside weather:', e);
                html = '';
            }
            ['currentOutside', 'fpCurrentOutside'].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.innerHTML = html;
            });
            ['dewpointOutside', 'fpDewpointOutside'].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.innerHTML = dpHtml;
            });
        }

        // Dew point via Magnus formula; inputs in °F / %, output in °F
        function calcDewPoint(tempF, humPct) {
            const tc = (tempF - 32) * 5 / 9;
            const a = 17.625, b = 243.04;
            const gamma = (a * tc / (b + tc)) + Math.log(humPct / 100);
            const dpC = b * gamma / (a - gamma);
            return dpC * 9 / 5 + 32;
        }

        function computeDewPointSeries(tempPts, humPts) {
            if (!tempPts || !humPts) return [];
            const len = Math.min(tempPts.length, humPts.length);
            const result = [];
            for (let i = 0; i < len; i++) {
                result.push({ t: tempPts[i].t, v: calcDewPoint(tempPts[i].v, humPts[i].v) });
            }
            return result;
        }

        function renderDewPointPanel(tempData, humData) {
            const container = document.getElementById('dewpointReadings');
            const fpContainer = document.getElementById('fpDewpointReadings');

            // Attic sensor
            const atticName = allSensors.find(n => n.toLowerCase() === 'attic');
            let atticDP = null;
            if (atticName) {
                const tPts = tempData[atticName];
                const hPts = humData[atticName];
                const t = tPts && tPts.length ? tPts[tPts.length - 1].v : null;
                const h = hPts && hPts.length ? hPts[hPts.length - 1].v : null;
                if (t !== null && h !== null) atticDP = calcDewPoint(t, h);
            }

            // Average favorites dew point
            let favDP = null;
            const favNames = [...favorites].filter(n => n !== '__favorites__');
            if (favNames.length > 0) {
                const dps = favNames.map(name => {
                    const tPts = tempData[name];
                    const hPts = humData[name];
                    const t = tPts && tPts.length ? tPts[tPts.length - 1].v : null;
                    const h = hPts && hPts.length ? hPts[hPts.length - 1].v : null;
                    return (t !== null && h !== null) ? calcDewPoint(t, h) : null;
                }).filter(v => v !== null);
                if (dps.length) favDP = dps.reduce((s, v) => s + v, 0) / dps.length;
            }

            const rows = [];

            if (atticDP !== null) {
                let deltaHtml = '';
                if (favDP !== null) {
                    const diff = atticDP - favDP;
                    const sign = diff >= 0 ? '+' : '';
                    const cls = diff > 0 ? 'wetter' : 'drier';
                    // outside wetter = higher dew point = bringing in more humidity
                    deltaHtml = `<span class="dp-delta ${cls}">${sign}${diff.toFixed(1)}&deg;</span>`;
                }
                rows.push(`<div class="dp-row">
                    <span class="dp-label" title="${atticName || 'Attic'}">Attic</span>
                    ${deltaHtml}
                    <span class="dp-value">${atticDP.toFixed(1)}&deg;</span>
                </div>`);
            }

            if (favDP !== null) {
                rows.push(`<div class="dp-row">
                    <span class="dp-label">Avg Indoor</span>
                    <span class="dp-value">${favDP.toFixed(1)}&deg;</span>
                </div>`);
            }

            const html = rows.length === 0
                ? '<div class="muted-note">No data — add favorites &amp; ensure Attic sensor is active.</div>'
                : rows.join('');
            if (container) container.innerHTML = html;
            if (fpContainer) fpContainer.innerHTML = html;
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

                const color = sensorColorMap[name] || COLORS[0];
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
                const color = sensorColorMap[name] || COLORS[0];
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
            applyHumModeUI();
            await loadSensors();
            // Load floor plan positions early
            try {
                const r = await fetch('/api/floorplan/positions');
                fpPositions = await r.json();
            } catch (e) { fpPositions = {}; }
            await loadData();
            renderFloorPlan();
            setInterval(loadData, 60000);
            loadOutside();
            setInterval(loadOutside, OUTSIDE_REFRESH_MS);
        })();
        </script>
    </body>
    </html>
    """
}
