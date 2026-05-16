#!/bin/bash
# ============================================================
# monitor.sh — System & Container Metrics Collection Script
# Runs every hour via cron. Saves report to /var/log/app-monitor/
#
# Cron setup:
#   0 * * * * /bin/bash /opt/Employee_Dashboard/monitoring/monitor.sh
#
# Metrics collected:
#   - Linux CPU usage
#   - Linux RAM usage
#   - Disk (ROM) usage
#   - Per-container CPU & RAM
#   - Container status (running/stopped)
#   - API response time
# ============================================================

REPORT_DIR="/var/log/app-monitor"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
REPORT_FILE="${REPORT_DIR}/report_${TIMESTAMP}.log"
API_URL="http://localhost/api/"

mkdir -p "$REPORT_DIR"

{
  echo "============================================"
  echo "  SYSTEM MONITORING REPORT"
  echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================"
  echo ""

  # ── Linux CPU Usage ──────────────────────────────────────
  echo "[ SERVER CPU USAGE ]"
  CPU_LINE=$(top -bn1 | grep -E "^(%Cpu|Cpu\(s\))")
  if echo "$CPU_LINE" | grep -q "ni,"; then
    CPU_IDLE=$(echo "$CPU_LINE" | awk '{for(i=1;i<=NF;i++) if($i~/^[0-9]/ && $(i+1)~/id/) print $i}')
  else
    CPU_IDLE=$(echo "$CPU_LINE" | grep -oP '[0-9.]+(?=\s*id)' | head -1)
  fi
  if [ -n "$CPU_IDLE" ]; then
    CPU_USED=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")
    echo "  CPU Used: ${CPU_USED}%"
    echo "  CPU Idle: ${CPU_IDLE}%"
  else
    CPU_USED=$(grep -oP '^\S+' /proc/stat | head -1 >/dev/null 2>&1 && \
      awk '/^cpu / {idle=$5; total=$2+$3+$4+$5+$6+$7+$8; used=total-idle; printf "%.1f", used/total*100}' /proc/stat || echo "N/A")
    echo "  CPU Used: ${CPU_USED}%"
    echo "  CPU Idle: N/A (calculated from /proc/stat)"
  fi
  echo ""

  # ── Linux RAM Usage ──────────────────────────────────────
  echo "[ SERVER RAM USAGE ]"
  free -h | awk '
    /^Mem:/ {
      printf "  Total RAM : %s\n", $2
      printf "  Used  RAM : %s\n", $3
      printf "  Free  RAM : %s\n", $4
    }
  '
  echo ""

  # ── Disk Usage ───────────────────────────────────────────
  echo "[ DISK (ROM) USAGE ]"
  df -h --output=source,size,used,avail,pcent,target | grep -v tmpfs | grep -v udev | grep -v snapfuse | grep -v "^none" | grep -v "/mnt/wsl"
  echo ""

  # ── Container Status ─────────────────────────────────────
  echo "[ CONTAINER STATUS ]"
  if command -v docker &>/dev/null; then
    docker ps -a --format "  Name: {{.Names}} | Status: {{.Status}} | Image: {{.Image}}"
  else
    echo "  Docker not available"
  fi
  echo ""

  # ── Per-Container CPU & RAM ──────────────────────────────
  echo "[ PER-CONTAINER CPU & RAM ]"
  if command -v docker &>/dev/null; then
    docker stats --no-stream --format \
      "  {{.Name}} | CPU: {{.CPUPerc}} | RAM: {{.MemUsage}} ({{.MemPerc}})"
  else
    echo "  Docker not available"
  fi
  echo ""

  # ── API Response Time ─────────────────────────────────────
  echo "[ API RESPONSE TIME ]"
  RESPONSE=$(curl -o /dev/null -s -w \
    "  HTTP Status : %{http_code}\n  Total Time  : %{time_total}s\n  Connect Time: %{time_connect}s\n" \
    --max-time 10 "$API_URL" 2>&1)
  if [ $? -eq 0 ]; then
    echo "$RESPONSE"
  else
    echo "  API unreachable at $API_URL"
  fi
  echo ""

  echo "============================================"
  echo "  END OF REPORT"
  echo "============================================"

} >> "$REPORT_FILE" 2>&1

# ── Retention: keep only the last 48 reports (48 hours) ────
ls -1t "${REPORT_DIR}"/report_*.log 2>/dev/null | tail -n +49 | xargs rm -f

echo "Report saved: $REPORT_FILE"
