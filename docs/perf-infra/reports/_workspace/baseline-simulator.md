# Baseline — Simulator (iPhone 17 / iOS 26.2 / Profile)

git: `56b5b63` (tag `baseline-render-pass-1`)
recorded: 2026-05-17T05:58:32Z

## 환경
- Xcode 26.2, Simulator iPhone 17, iOS 26.2
- Configuration: Profile

## 시나리오 7개 통과 / 1개 fixture 이슈 (goal-detail-nav skipped)

## 메트릭

### home-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 101.581 | 32.768 | 163.840 | 65.944 |
| CPU Instructions Retired | kI | 142316.978 | 139439.520 | 145076.956 | 2367.092 |
| Clock Monotonic Time | s | 4.694 | 4.565 | 4.797 | 0.117 |
| CPU Cycles | kC | 116020.552 | 112718.930 | 122278.874 | 4044.905 |
| CPU Time | s | 0.043 | 0.041 | 0.046 | 0.002 |
| Memory Peak Physical | kB | 37700.966 | 37510.912 | 37904.128 | 174.010 |

### home-scroll

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 271.974 | 98.304 | 442.368 | 132.902 |
| CPU Instructions Retired | kI | 1551257.374 | 1540122.901 | 1562745.883 | 10248.991 |
| Clock Monotonic Time | s | 6.717 | 5.161 | 12.878 | 3.444 |
| CPU Cycles | kC | 986122.005 | 966685.627 | 1027841.029 | 25652.606 |
| CPU Time | s | 0.347 | 0.340 | 0.353 | 0.005 |
| Memory Peak Physical | kB | 40030.963 | 39477.184 | 40476.608 | 378.148 |

### home-nav

| (no measure metrics) |  |  |  |  |  |

### stats-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 88.474 | -49.152 | 196.608 | 97.344 |
| CPU Instructions Retired | kI | 143329.549 | 142336.088 | 144503.486 | 834.026 |
| Clock Monotonic Time | s | 4.645 | 4.558 | 4.689 | 0.052 |
| CPU Cycles | kC | 117512.554 | 113309.515 | 120036.485 | 2646.737 |
| CPU Time | s | 0.043 | 0.040 | 0.045 | 0.002 |
| Memory Peak Physical | kB | 38143.462 | 37986.176 | 38264.704 | 105.927 |

### stats-scroll

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 176.947 | 98.304 | 311.296 | 92.246 |
| CPU Instructions Retired | kI | 1565371.102 | 1560326.489 | 1572087.146 | 4808.852 |
| Clock Monotonic Time | s | 7.593 | 5.034 | 13.201 | 3.700 |
| CPU Cycles | kC | 983575.089 | 973506.874 | 997764.910 | 11942.133 |
| CPU Time | s | 0.341 | 0.334 | 0.351 | 0.006 |
| Memory Peak Physical | kB | 39680.154 | 39362.304 | 39935.744 | 218.160 |

### stats-nav

| (no measure metrics) |  |  |  |  |  |

### goal-detail-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 114.688 | 0.000 | 212.992 | 89.739 |
| CPU Instructions Retired | kI | 141588.305 | 138411.271 | 145211.373 | 2431.765 |
| Clock Monotonic Time | s | 4.549 | 4.474 | 4.590 | 0.046 |
| CPU Cycles | kC | 115889.575 | 111345.809 | 124028.728 | 4781.314 |
| CPU Time | s | 0.044 | 0.041 | 0.046 | 0.002 |
| Memory Peak Physical | kB | 37786.291 | 37560.192 | 37953.408 | 144.885 |
