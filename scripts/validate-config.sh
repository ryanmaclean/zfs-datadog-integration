#!/bin/sh
# ZFS Datadog Integration - Configuration Validator
# Validates configuration and checks connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Detect OS and set paths
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="$ID"
else
    OS_TYPE="unknown"
fi

case "$OS_TYPE" in
    freebsd|truenas)
        ZED_DIR="/usr/local/etc/zfs/zed.d"
        ;;
    *)
        ZED_DIR="/etc/zfs/zed.d"
        ;;
esac

printf '%sZFS Datadog Configuration Validator%s\n' "$GREEN" "$NC"
printf '====================================\n\n'

# Check if config exists
printf '1. Checking configuration file...\n'
if [ -f "$ZED_DIR/config.sh" ]; then
    printf '   %s✓%s Found: %s/config.sh\n' "$GREEN" "$NC" "$ZED_DIR"
    # shellcheck disable=SC1091  # config.sh lives alongside the installed zedlets at runtime, not in this checkout
    . "$ZED_DIR/config.sh"
elif [ -f "$(dirname "$0")/config.sh" ]; then
    printf '   %s✓%s Found: %s/config.sh\n' "$GREEN" "$NC" "$(dirname "$0")"
    # shellcheck disable=SC1091  # config.sh lives alongside the installed zedlets at runtime, not in this checkout
    . "$(dirname "$0")/config.sh"
else
    printf '   %s✗%s Configuration file not found\n' "$RED" "$NC"
    printf '     Expected: %s/config.sh\n' "$ZED_DIR"
    printf '     Run: sudo cp config.sh.example config.sh\n'
    ERRORS=$((ERRORS + 1))
fi

# Validate DD_API_KEY
printf '\n2. Validating Datadog API Key...\n'
if [ -z "$DD_API_KEY" ]; then
    printf '   %s✗%s DD_API_KEY is not set\n' "$RED" "$NC"
    ERRORS=$((ERRORS + 1))
elif [ "$DD_API_KEY" = "your_api_key_here" ]; then
    printf '   %s✗%s DD_API_KEY is still set to placeholder value\n' "$RED" "$NC"
    printf '     Get your key from: https://app.datadoghq.com/organization-settings/api-keys\n'
    ERRORS=$((ERRORS + 1))
elif [ ${#DD_API_KEY} -ne 32 ]; then
    printf '   %s⚠%s  DD_API_KEY length is %s (expected 32)\n' "$YELLOW" "$NC" "${#DD_API_KEY}"
    printf '     This may be valid but is unusual\n'
    WARNINGS=$((WARNINGS + 1))
else
    printf '   %s✓%s DD_API_KEY is set (%s chars)\n' "$GREEN" "$NC" "${#DD_API_KEY}"
fi

# Check DD_SITE
printf '\n3. Checking Datadog Site...\n'
if [ -n "$DD_SITE" ]; then
    printf '   %s✓%s DD_SITE: %s\n' "$GREEN" "$NC" "$DD_SITE"
else
    printf '   %s⚠%s  DD_SITE not set, using default: datadoghq.com\n' "$YELLOW" "$NC"
    WARNINGS=$((WARNINGS + 1))
fi

# Check ZED
printf '\n4. Checking ZFS Event Daemon...\n'
if command -v zed >/dev/null 2>&1; then
    printf '   %s✓%s ZED binary found\n' "$GREEN" "$NC"
else
    printf '   %s✗%s ZED binary not found\n' "$RED" "$NC"
    printf '     Install OpenZFS/ZFS first\n'
    ERRORS=$((ERRORS + 1))
fi

# Check if ZED is running
case "$OS_TYPE" in
    freebsd|truenas)
        if service zfs status >/dev/null 2>&1; then
            printf '   %s✓%s ZED is running\n' "$GREEN" "$NC"
        else
            printf '   %s⚠%s  ZED may not be running\n' "$YELLOW" "$NC"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
    *)
        if systemctl is-active --quiet zfs-zed 2>/dev/null; then
            printf '   %s✓%s ZED is running (systemd)\n' "$GREEN" "$NC"
        elif service zfs-zed status >/dev/null 2>&1; then
            printf '   %s✓%s ZED is running (init)\n' "$GREEN" "$NC"
        else
            printf '   %s⚠%s  ZED may not be running\n' "$YELLOW" "$NC"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
esac

# Check zedlets
printf '\n5. Checking installed zedlets...\n'
ZEDLETS_FOUND=0
for zedlet in scrub_finish-datadog.sh resilver_finish-datadog.sh statechange-datadog.sh; do
    if [ -f "$ZED_DIR/$zedlet" ]; then
        ZEDLETS_FOUND=$((ZEDLETS_FOUND + 1))
    fi
done

if [ $ZEDLETS_FOUND -eq 0 ]; then
    printf '   %s✗%s No zedlets found in %s\n' "$RED" "$NC" "$ZED_DIR"
    printf '     Run: sudo ./install.sh\n'
    ERRORS=$((ERRORS + 1))
elif [ $ZEDLETS_FOUND -lt 3 ]; then
    printf '   %s⚠%s  Found %s/3 core zedlets\n' "$YELLOW" "$NC" "$ZEDLETS_FOUND"
    WARNINGS=$((WARNINGS + 1))
else
    printf '   %s✓%s Found %s core zedlets\n' "$GREEN" "$NC" "$ZEDLETS_FOUND"
fi

# Check network connectivity to Datadog
printf '\n6. Testing Datadog API connectivity...\n'
if [ -n "$DD_API_KEY" ] && [ "$DD_API_KEY" != "your_api_key_here" ]; then
    if command -v curl >/dev/null 2>&1; then
        DD_URL="${DD_API_URL:-https://api.datadoghq.com}"
        if curl -s -m 5 -H "DD-API-KEY: $DD_API_KEY" "$DD_URL/api/v1/validate" >/dev/null 2>&1; then
            printf '   %s✓%s Successfully connected to Datadog API\n' "$GREEN" "$NC"
        else
            printf '   %s⚠%s  Could not connect to Datadog API\n' "$YELLOW" "$NC"
            printf '     Check network connectivity and API key\n'
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        printf '   %s⚠%s  curl not found, skipping connectivity test\n' "$YELLOW" "$NC"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    printf '   %s⚠%s  Skipping (API key not configured)\n' "$YELLOW" "$NC"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Datadog Agent (optional)
printf '\n7. Checking Datadog Agent (optional)...\n'
if command -v datadog-agent >/dev/null 2>&1; then
    printf '   %s✓%s Datadog Agent found\n' "$GREEN" "$NC"
    if datadog-agent status >/dev/null 2>&1; then
        printf '   %s✓%s Datadog Agent is running\n' "$GREEN" "$NC"
    else
        printf '   %s⚠%s  Datadog Agent is not running\n' "$YELLOW" "$NC"
        printf '     Metrics via DogStatsD will not work\n'
        WARNINGS=$((WARNINGS + 1))
    fi
else
    printf '   %s⚠%s  Datadog Agent not found\n' "$YELLOW" "$NC"
    printf '     Events will work, but metrics will not\n'
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
printf '\n'
printf '====================================\n'
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    printf '%s✓ All checks passed!%s\n' "$GREEN" "$NC"
    printf '\nConfiguration is valid and ready to use.\n'
    exit 0
elif [ $ERRORS -eq 0 ]; then
    printf '%s⚠ Validation completed with %s warning(s)%s\n' "$YELLOW" "$WARNINGS" "$NC"
    printf '\nConfiguration should work, but check warnings above.\n'
    exit 0
else
    printf '%s✗ Validation failed with %s error(s) and %s warning(s)%s\n' "$RED" "$ERRORS" "$WARNINGS" "$NC"
    printf '\nPlease fix the errors above before using the integration.\n'
    exit 1
fi
