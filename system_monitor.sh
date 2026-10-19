#!/usr/bin/env bash

set -euo pipefail

collect_metrics() {
    memory="$(awk '
        /^MemTotal:/ { total = $2 }
        /^MemFree:/ { free = $2 }
        /^MemAvailable:/ { available = $2 }
        END {
            printf "%.0f;%.0f;%.2f",
                total / 1024, free / 1024,
                100 * (total - available) / total
        }
    ' /proc/meminfo)"

    first="$(head -n 1 /proc/stat)"
    sleep 1
    second="$(head -n 1 /proc/stat)"

    cpu="$(printf '%s\n%s\n' "$first" "$second" | awk '
    {
        total = 0
        for (i = 2; i <= 9; i++) total += $i
        idle = $5 + $6

        if (NR == 1) {
            total1 = total
            idle1 = idle
        } else {
            delta_total = total - total1
            delta_idle = idle - idle1

            if (delta_total > 0)
                printf "%.2f", 100 * (delta_total - delta_idle) / delta_total
            else
                printf "0.00"
        }
    }')"

    disk="$(df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"

    load="$(awk '{ print $1 }' /proc/loadavg)"

    timestamp="$(date '+%d.%m.%Y %H:%M:%S')"

    csv_file="system_report_$(date '+%Y-%m-%d').csv"

    if [ ! -f "$csv_file" ]; then
        printf '%s\n' 'timestamp;all_memory;free_memory;%memory_used;%cpu_used;%disk_used;load_average_1m' > "$csv_file"
    fi

    printf '%s;%s;%s;%s;%s\n' \
        "$timestamp" "$memory" "$cpu" "$disk" "$load" >> "$csv_file"

    echo "Измерение сохранено в $csv_file"
}

pid_file="system_monitor.pid"

is_monitor_running() {
    [ -f "$pid_file" ] || return 1

    pid="$(cat "$pid_file")"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1

    kill -0 "$pid" 2>/dev/null || return 1

    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1

    [[ "$cmdline" == *"system_monitor.sh RUN"* ]]
}

if [ "${1:-}" = "START" ]; then
    if is_monitor_running; then
        echo "Мониторинг уже запущен (PID: $(cat "$pid_file"))."
        exit 1
    fi

    nohup bash "$0" RUN > system_monitor.log 2>&1 < /dev/null &
    echo "$!" > "$pid_file"
    echo "Мониторинг запущен (PID: $!)."

elif [ "${1:-}" = "STATUS" ]; then
    if is_monitor_running; then
        echo "Мониторинг работает (PID: $(cat "$pid_file"))."
    else
        echo "Мониторинг не запущен."
    fi

elif [ "${1:-}" = "STOP" ]; then
    if is_monitor_running; then
        pid="$(cat "$pid_file")"
        kill "$pid"
        rm -f "$pid_file"
        echo "Мониторинг остановлен (PID: $pid)."
    else
        rm -f "$pid_file"
        echo "Мониторинг не запущен."
    fi

elif [ "${1:-}" = "RUN" ]; then
    while true; do
        collect_metrics
        sleep "${MONITOR_INTERVAL:-600}"
    done

else
    collect_metrics
fi

