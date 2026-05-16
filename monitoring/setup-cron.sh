#!/bin/bash
# ============================================================
# setup-cron.sh — Installs monitor.sh as an hourly cron job
# Run once on the server after deployment:
#   sudo bash monitoring/setup-cron.sh
# ============================================================

SCRIPT_PATH="$(realpath "$(dirname "$0")/monitor.sh")"
CRON_JOB="0 * * * * /bin/bash ${SCRIPT_PATH} >> /var/log/app-monitor/cron.log 2>&1"

chmod +x "$SCRIPT_PATH"

# Add cron job only if it doesn't exist already
(crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH") && {
  echo "Cron job already exists. No changes made."
  exit 0
}

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job installed:"
echo "  $CRON_JOB"
echo ""
echo "Verify with: crontab -l"
echo "Reports will be saved to: /var/log/app-monitor/"
