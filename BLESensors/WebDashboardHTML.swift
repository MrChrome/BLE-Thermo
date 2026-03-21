enum WebDashboardHTML {
    static let page = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>BLE Thermo</title>
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
            }
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
            .controls-row .range-picker {
                margin-bottom: 0;
            }
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
            .sensor-select option {
                background: #1a1a2e;
                color: #e0e0e0;
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
        </style>
    </head>
    <body>
        <div class="container">
            <h1>BLE Thermo</h1>
            <div class="controls-row">
                <div class="range-picker" id="rangePicker"></div>
                <select class="sensor-select" id="sensorSelect">
                    <option value="">All Sensors</option>
                </select>
            </div>
            <div class="chart-card">
                <h2>Temperature (&deg;F)</h2>
                <div class="chart-wrap"><canvas id="tempChart"></canvas></div>
            </div>
            <div class="chart-card">
                <h2>Humidity (%)</h2>
                <div class="chart-wrap"><canvas id="humChart"></canvas></div>
            </div>
        </div>
        <script>
        const RANGES = [
            { key: 'hour',      label: '1 Hour' },
            { key: '6h',        label: '6 Hours' },
            { key: 'today',     label: 'Today' },
            { key: 'yesterday', label: 'Yesterday' },
            { key: 'day',       label: '1 Day' },
            { key: 'month',     label: '1 Month' },
            { key: 'year',      label: '1 Year' }
        ];
        const COLORS = [
            '#4A9EFF','#34D399','#F472B6','#FBBF24',
            '#A78BFA','#F87171','#38BDF8','#FB923C'
        ];

        let currentRange = 'day';
        let currentSensor = '';  // empty = all sensors
        let allSensors = [];
        let sensorColorMap = {};
        let tempChart = null;
        let humChart = null;

        const sensorSelect = document.getElementById('sensorSelect');
        sensorSelect.onchange = () => {
            currentSensor = sensorSelect.value;
            loadData();
        };

        // Build range picker buttons
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
            return Object.entries(seriesData)
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
                            labels: { color: 'rgba(255,255,255,0.7)', boxWidth: 12, padding: 16 }
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
            // Preserve hidden state of each dataset by label
            const hiddenByLabel = {};
            chart.data.datasets.forEach((ds, i) => {
                hiddenByLabel[ds.label] = !chart.isDatasetVisible(i);
            });
            chart.data.datasets = datasets;
            chart.options.scales.x.time.unit = unit;
            chart.update();
            // Restore hidden state
            chart.data.datasets.forEach((ds, i) => {
                if (hiddenByLabel[ds.label]) {
                    chart.hide(i);
                }
            });
        }

        function renderSensorSelect() {
            sensorSelect.innerHTML = '<option value="">All Sensors</option>';
            allSensors.forEach(name => {
                const opt = document.createElement('option');
                opt.value = name;
                opt.textContent = name;
                sensorSelect.appendChild(opt);
            });
            sensorSelect.value = currentSensor;
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
                if (currentSensor) url += '&sensor=' + encodeURIComponent(currentSensor);
                const resp = await fetch(url);
                const data = await resp.json();
                const unit = timeUnit(currentRange);

                const tempDS = buildDatasets(data.temperature);
                const humDS = buildDatasets(data.humidity);

                if (!tempChart) {
                    tempChart = makeChart(document.getElementById('tempChart'), tempDS, unit);
                    humChart = makeChart(document.getElementById('humChart'), humDS, unit);
                } else {
                    updateChart(tempChart, tempDS, unit);
                    updateChart(humChart, humDS, unit);
                }
            } catch (e) {
                console.error('Failed to load data:', e);
            }
        }

        // Init
        (async () => {
            await loadSensors();
            await loadData();
            setInterval(loadData, 60000);
        })();
        </script>
    </body>
    </html>
    """
}
