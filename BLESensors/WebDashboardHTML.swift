enum WebDashboardHTML {
    static let page = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>BLE Thermo</title>
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
                <button class="fav-btn" id="favBtn" title="Add to favorites">&#9733;</button>
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
        let favorites = new Set(JSON.parse(localStorage.getItem('bleFavorites') || '[]'));

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
            const isSpecificSensor = currentSensor && currentSensor !== '__favorites__';
            if (!isSpecificSensor) {
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

            // Add a dashed average line when a single sensor is selected
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
            // Find the x extent across all sensor datasets
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
                    label: temp + '\u{00B0}F',
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

        function syncHiddenToChart(chart, hiddenByLabel) {
            chart.data.datasets.forEach((ds, i) => {
                const meta = chart.getDatasetMeta(i);
                meta.hidden = hiddenByLabel[ds.label] || false;
            });
            chart.update('none');
        }

        function legendClickHandler(e, legendItem, legend) {
            const label = legendItem.text;
            const chart = legend.chart;
            const index = chart.data.datasets.findIndex(ds => ds.label === label);
            if (index === -1) return;
            // Don't sync avg/reference lines across charts
            if (chart.data.datasets[index].isAvgLine || chart.data.datasets[index].isRefLine) {
                const meta = chart.getDatasetMeta(index);
                meta.hidden = !meta.hidden;
                chart.update('none');
                return;
            }

            // Toggle visibility on clicked chart
            const meta = chart.getDatasetMeta(index);
            meta.hidden = !meta.hidden;
            chart.update('none');

            // Mirror to the other chart
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
            // Preserve hidden state of each dataset by label before replacing data (skip avg lines)
            const hiddenByLabel = {};
            chart.data.datasets.forEach((ds, i) => {
                if (!ds.isAvgLine) hiddenByLabel[ds.label] = !chart.isDatasetVisible(i);
            });
            chart.data.datasets = datasets;
            chart.options.scales.x.time.unit = unit;
            // Restore hidden state directly on metadata before update so tooltips work correctly
            chart.data.datasets.forEach((ds, i) => {
                const meta = chart.getDatasetMeta(i);
                meta.hidden = hiddenByLabel[ds.label] || false;
            });
            // 'none' skips animation on refresh
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
