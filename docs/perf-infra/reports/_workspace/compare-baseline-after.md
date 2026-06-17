# Phase 5 — After vs Baseline 비교

after git: `e786fc9` (baseline tag: `baseline-render-pass-1` = `56b5b63`)
recorded: 2026-05-17T06:27:34Z

회귀 임계치: ±10% (Phase 0 확정). 🔴 = regression, 🟢 = improvement.


## simulator

### home-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 116020.552 | 121353.876 | +4.6% |
| CPU Instructions Retired | kI | 142316.978 | 145971.758 | +2.6% |
| CPU Time | s | 0.043 | 0.045 | +4.8% |
| Clock Monotonic Time | s | 4.694 | 4.851 | +3.3% |
| Memory Peak Physical | kB | 37700.966 | 38078.054 | +1.0% |
| Memory Physical | kB | 101.581 | 45.875 | -54.8% 🟢 |

### home-scroll

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 986122.005 | 986280.570 | +0.0% |
| CPU Instructions Retired | kI | 1551257.374 | 1551876.281 | +0.0% |
| CPU Time | s | 0.347 | 0.345 | -0.4% |
| Clock Monotonic Time | s | 6.717 | 6.763 | +0.7% |
| Memory Peak Physical | kB | 40030.963 | 39545.933 | -1.2% |
| Memory Physical | kB | 271.974 | 203.162 | -25.3% 🟢 |

### home-nav  _(no metrics)_
### stats-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 117512.554 | 121713.460 | +3.6% |
| CPU Instructions Retired | kI | 143329.549 | 157100.462 | +9.6% |
| CPU Time | s | 0.043 | 0.045 | +5.3% |
| Clock Monotonic Time | s | 4.645 | 4.638 | -0.1% |
| Memory Peak Physical | kB | 38143.462 | 37982.899 | -0.4% |
| Memory Physical | kB | 88.474 | 91.750 | +3.7% |

### stats-scroll

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 983575.089 | 976749.390 | -0.7% |
| CPU Instructions Retired | kI | 1565371.102 | 1560264.628 | -0.3% |
| CPU Time | s | 0.341 | 0.337 | -1.1% |
| Clock Monotonic Time | s | 7.593 | 7.642 | +0.6% |
| Memory Peak Physical | kB | 39680.154 | 39775.245 | +0.2% |
| Memory Physical | kB | 176.947 | 281.805 | +59.3% 🔴 |

### stats-nav  _(no metrics)_
### goal-detail-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 115889.575 | 125059.356 | +7.9% |
| CPU Instructions Retired | kI | 141588.305 | 159122.443 | +12.4% 🔴 |
| CPU Time | s | 0.044 | 0.047 | +6.9% |
| Clock Monotonic Time | s | 4.549 | 4.556 | +0.1% |
| Memory Peak Physical | kB | 37786.291 | 38195.891 | +1.1% |
| Memory Physical | kB | 114.688 | 32.768 | -71.4% 🟢 |


## device

### home-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 167760.104 | 166653.557 | -0.7% |
| CPU Instructions Retired | kI | 241440.798 | 239659.878 | -0.7% |
| CPU Time | s | 0.129 | 0.132 | +2.3% |
| Clock Monotonic Time | s | 3.585 | 3.587 | +0.1% |
| Memory Peak Physical | kB | 15015.266 | 15064.394 | +0.3% |
| Memory Physical | kB | -150.733 | -157.286 | +4.3% |

### home-scroll

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 1354406.082 | 1338334.294 | -1.2% |
| CPU Instructions Retired | kI | 3753244.208 | 3761125.245 | +0.2% |
| CPU Time | s | 0.803 | 0.797 | -0.7% |
| Clock Monotonic Time | s | 8.180 | 8.140 | -0.5% |
| Memory Peak Physical | kB | 15339.645 | 15860.680 | +3.4% |
| Memory Physical | kB | 85.197 | 72.090 | -15.4% 🟢 |

### home-nav  _(no metrics)_
### stats-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 168322.002 | 161972.033 | -3.8% |
| CPU Instructions Retired | kI | 246593.613 | 242838.074 | -1.5% |
| CPU Time | s | 0.127 | 0.128 | +0.7% |
| Clock Monotonic Time | s | 3.593 | 3.627 | +1.0% |
| Memory Peak Physical | kB | 15018.566 | 15044.733 | +0.2% |
| Memory Physical | kB | -147.456 | -157.286 | +6.7% |

### stats-scroll

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 1299780.222 | 1307712.395 | +0.6% |
| CPU Instructions Retired | kI | 3361527.430 | 3376818.303 | +0.5% |
| CPU Time | s | 0.811 | 0.812 | +0.1% |
| Clock Monotonic Time | s | 9.116 | 9.145 | +0.3% |
| Memory Peak Physical | kB | 15660.771 | 15621.450 | -0.3% |
| Memory Physical | kB | 39.322 | 55.706 | +41.7% 🔴 |

### stats-nav  _(no metrics)_
### goal-detail-cold

| metric | unit | baseline avg | after avg | Δ |
|---|---|---:|---:|---|
| CPU Cycles | kC | 152998.432 | 151491.122 | -1.0% |
| CPU Instructions Retired | kI | 196821.231 | 195403.566 | -0.7% |
| CPU Time | s | 0.128 | 0.128 | -0.6% |
| Clock Monotonic Time | s | 3.553 | 3.564 | +0.3% |
| Memory Peak Physical | kB | 15057.840 | 14966.090 | -0.6% |
| Memory Physical | kB | -111.411 | -117.965 | +5.9% |
