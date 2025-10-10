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

printf "${GREEN}ZFS Datadog Configuration Validator${NC}\n"
printf "====================================\n\n"

# Check if config exists
printf "1. Checking configuration file...\n"
if [ -f "$ZED_DIR/config.sh" ]; then
    printf "   ${GREEN}✓${NC} Found: $ZED_DIR/config.sh\n"
    . "$ZED_DIR/config.sh"
elif [ -f "$(dirname "$0")/config.sh" ]; then
    printf "   ${GREEN}✓${NC} Found: $(dirname "$0")/config.sh\n"
    . "$(dirname "$0")/config.sh"
else
    printf "   ${RED}✗${NC} Configuration file not found\n"
    printf "     Expected: $ZED_DIR/config.sh\n"
    printf "     Run: sudo cp config.sh.example config.sh\n"
    ERRORS=$((ERRORS + 1))
fi

# Validate DD_API_KEY
printf "\n2. Validating Datadog API Key...\n"
if [ -z "$DD_API_KEY" ]; then
    printf "   ${RED}✗${NC} DD_API_KEY is not set\n"
    ERRORS=$((ERRORS + 1))
elif [ "$DD_API_KEY" = "your_api_key_here" ]; then
    printf "   ${RED}✗${NC} DD_API_KEY is still set to placeholder value\n"
    printf "     Get your key from: https://app.datadoghq.com/organization-settings/api-keys\n"
    ERRORS=$((ERRORS + 1))
elif [ ${#DD_API_KEY} -ne 32 ]; then
    printf "   ${YELLOW}⚠${NC}  DD_API_KEY length is ${#DD_API_KEY} (expected 32)\n"
    printf "     This may be valid but is unusual\n"
    WARNINGS=$((WARNINGS + 1))
else
    printf "   ${GREEN}✓${NC} DD_API_KEY is set (${#DD_API_KEY} chars)\n"
fi

# Check DD_SITE
printf "\n3. Checking Datadog Site...\n"
if [ -n "$DD_SITE" ]; then
    printf "   ${GREEN}✓${NC} DD_SITE: $DD_SITE\n"
else
    printf "   ${YELLOW}⚠${NC}  DD_SITE not set, using default: datadoghq.com\n"
    WARNINGS=$((WARNINGS + 1))
fi

# Check ZED
printf "\n4. Checking ZFS Event Daemon...\n"
if command -v zed >/dev/null 2>&1; then
    printf "   ${GREEN}✓${NC} ZED binary found\n"
else
    printf "   ${RED}✗${NC} ZED binary not found\n"
    printf "     Install OpenZFS/ZFS first\n"
    ERRORS=$((ERRORS + 1))
fi

# Check if ZED is running
case "$OS_TYPE" in
    freebsd|truenas)
        if service zfs status >/dev/null 2>&1; then
            printf "   ${GREEN}✓${NC} ZED is running\n"
        else
            printf "   ${YELLOW}⚠${NC}  ZED may not be running\n"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
    *)
        if systemctl is-active --quiet zfs-zed 2>/dev/null; then
            printf "   ${GREEN}✓${NC} ZED is running (systemd)\n"
        elif service zfs-zed status >/dev/null 2>&1; then
            printf "   ${GREEN}✓${NC} ZED is running (init)\n"
        else
            printf "   ${YELLOW}⚠${NC}  ZED may not be running\n"
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
esac

# Check zedlets
printf "\n5. Checking installed zedlets...\n"
ZEDLETS_FOUND=0
for zedlet in scrub_finish-datadog.sh resilver_finish-datadog.sh statechange-datadog.sh; do
    if [ -f "$ZED_DIR/$zedlet" ]; then
        ZEDLETS_FOUND=$((ZEDLETS_FOUND + 1))
    fi
done

if [ $ZEDLETS_FOUND -eq 0 ]; then
    printf "   ${RED}✗${NC} No zedlets found in $ZED_DIR\n"
    printf "     Run: sudo ./install.sh\n"
    ERRORS=$((ERRORS + 1))
elif [ $ZEDLETS_FOUND -lt 3 ]; then
    printf "   ${YELLOW}⚠${NC}  Found $ZEDLETS_FOUND/3 core zedlets\n"
    WARNINGS=$((WARNINGS + 1))
else
    printf "   ${GREEN}✓${NC} Found $ZEDLETS_FOUND core zedlets\n"
fi

# Check network connectivity to Datadog
printf "\n6. Testing Datadog API connectivity...\n"
if [ -n "$DD_API_KEY" ] && [ "$DD_API_KEY" != "your_api_key_here" ]; then
    if command -v curl >/dev/null 2>&1; then
        DD_URL="${DD_API_URL:-https://api.datadoghq.com}"
        if curl -s -m 5 -H "DD-API-KEY: $DD_API_KEY" "$DD_URL/api/v1/validate" >/dev/null 2>&1; then
            printf "   ${GREEN}✓${NC} Successfully connected to Datadog API\n"
        else
            printf "   ${YELLOW}⚠${NC}  Could not connect to Datadog API\n"
            printf "     Check network connectivity and API key\n"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        printf "   ${YELLOW}⚠${NC}  curl not found, skipping connectivity test\n"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    printf "   ${YELLOW}⚠${NC}  Skipping (API key not configured)\n"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Datadog Agent (optional)
printf "\n7. Checking Datadog Agent (optional)...\n"
if command -v datadog-agent >/dev/null 2>&1; then
    printf "   ${GREEN}✓${NC} Datadog Agent found\n"
    if datadog-agent status >/dev/null 2>&1; then
        printf "   ${GREEN}✓${NC} Datadog Agent is running\n"
    else
        printf "   ${YELLOW}⚠${NC}  Datadog Agent is not running\n"
        printf "     Metrics via DogStatsD will not work\n"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    printf "   ${YELLOW}⚠${NC}  Datadog Agent not found\n"
    printf "     Events will work, but metrics will not\n"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
printf "\n"
printf "====================================\n"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    printf "${GREEN}✓ All checks passed!${NC}\n"
    printf "\nConfiguration is valid and ready to use.\n"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    printf "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}\n"
    printf "\nConfiguration should work, but check warnings above.\n"
    exit 0
else
    printf "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}\n"
    printf "\nPlease fix the errors above before using the integration.\n"
    exit 1
fi
