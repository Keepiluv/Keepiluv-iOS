# Baseline — Device (Jiyong의 iPhone / Profile)

git: `56b5b63` (tag `baseline-render-pass-1`)
recorded: 2026-05-17T05:58:31Z

## 환경
- Device: Jiyong의 iPhone (UDID 00008110-00096DC42632801E)
- Configuration: Profile

## 시나리오 7개 통과 / 1개 fixture 이슈

goal-detail-nav: 시뮬레이터와 동일하게 fixture 가 `isCompleted=true && isEditing=false` 로 떠 `bottomButton` 미렌더. 실기기에서도 동일 원인으로 skip.

## 메트릭

### home-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | -150.733 | -638.976 | -16.384 | 273.274 |
| CPU Instructions Retired | kI | 241440.798 | 238097.692 | 248884.724 | 4548.963 |
| Clock Monotonic Time | s | 3.585 | 3.580 | 3.591 | 0.005 |
| CPU Cycles | kC | 167760.104 | 160705.136 | 171429.984 | 4106.200 |
| CPU Time | s | 0.129 | 0.126 | 0.134 | 0.004 |
| Memory Peak Physical | kB | 15015.266 | 14828.488 | 15533.000 | 291.847 |

### home-scroll

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 85.197 | -32.768 | 163.840 | 78.061 |
| CPU Instructions Retired | kI | 3753244.208 | 3655730.192 | 4119814.358 | 204957.731 |
| Clock Monotonic Time | s | 8.180 | 6.260 | 14.220 | 3.445 |
| CPU Cycles | kC | 1354406.082 | 1334529.826 | 1408104.247 | 30292.098 |
| CPU Time | s | 0.803 | 0.795 | 0.809 | 0.006 |
| Memory Peak Physical | kB | 15339.645 | 15188.912 | 15565.744 | 152.556 |

### home-nav

| (no measure metrics) |  |  |  |  |  |

### stats-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | -147.456 | -524.288 | 16.384 | 217.358 |
| CPU Instructions Retired | kI | 246593.613 | 240047.717 | 257215.214 | 7332.838 |
| Clock Monotonic Time | s | 3.593 | 3.518 | 3.682 | 0.060 |
| CPU Cycles | kC | 168322.002 | 156149.886 | 185529.097 | 13787.423 |
| CPU Time | s | 0.127 | 0.117 | 0.138 | 0.009 |
| Memory Peak Physical | kB | 15018.566 | 14812.128 | 15516.640 | 287.211 |

### stats-scroll

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | 39.322 | -163.840 | 147.456 | 118.487 |
| CPU Instructions Retired | kI | 3361527.430 | 3182261.716 | 3656675.168 | 241946.243 |
| Clock Monotonic Time | s | 9.116 | 6.164 | 14.069 | 4.040 |
| CPU Cycles | kC | 1299780.222 | 1273744.973 | 1336138.412 | 30156.601 |
| CPU Time | s | 0.811 | 0.787 | 0.834 | 0.019 |
| Memory Peak Physical | kB | 15660.771 | 15532.976 | 15811.504 | 100.598 |

### stats-nav

| (no measure metrics) |  |  |  |  |  |

### goal-detail-cold

| metric | unit | avg | min | max | stddev |
|---|---|---|---|---|---|
| Memory Physical | kB | -111.411 | -344.064 | 0.000 | 154.306 |
| CPU Instructions Retired | kI | 196821.231 | 194186.385 | 200441.984 | 2926.160 |
| Clock Monotonic Time | s | 3.553 | 3.527 | 3.570 | 0.017 |
| CPU Cycles | kC | 152998.432 | 148684.243 | 159690.249 | 5408.908 |
| CPU Time | s | 0.128 | 0.121 | 0.136 | 0.007 |
| Memory Peak Physical | kB | 15057.840 | 14877.616 | 15418.288 | 254.875 |
