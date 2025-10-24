#!/bin/bash
# Apply JWT Validation Policies to APIM Operations
# Simple Azure CLI-based script

set -e

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-mba-prod}"
APIM_SERVICE="${APIM_SERVICE:-apim-mba-001}"
API_ID="${API_ID:-mybartenderai-api}"
DRY_RUN="${DRY_RUN:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Operations requiring JWT (Premium/Pro features)
OPERATIONS_WITH_JWT=(
    "askBartender"
    "recommendCocktails"
    "getSpeechToken"
)

# Operations without JWT (public/all tiers)
PUBLIC_OPERATIONS=(
    "getLatestSnapshot"
    "getHealth"
    "getImageManifest"
    "triggerSync"
)

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  JWT Policy Deployment Script (Azure CLI)${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  APIM Service: $APIM_SERVICE"
echo "  API: $API_ID"
echo "  Dry Run: $DRY_RUN"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="$SCRIPT_DIR/../policies/jwt-validation-entra-external-id.xml"

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Error: JWT policy file not found: $POLICY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}JWT policy file found: $POLICY_FILE${NC}"
echo ""

# Get subscription ID
echo -e "${YELLOW}Getting Azure subscription information...${NC}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "  Subscription ID: $SUBSCRIPTION_ID"
echo ""

# Counters
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

# Function to apply policy to an operation
apply_policy() {
    local operation_id=$1

    echo -e "${YELLOW}Processing operation: $operation_id${NC}"
    echo -e "  ${CYAN}Type: Premium/Pro (requires JWT)${NC}"

    # Read policy content, remove BOM if present
    POLICY_CONTENT=$(cat "$POLICY_FILE" | sed '1s/^\xEF\xBB\xBF//')

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${MAGENTA}[DRY RUN] Would apply JWT policy${NC}"
        echo -e "  ${GREEN}✓ Success (dry run)${NC}"
        echo ""
        return 0
    fi

    # Create temp file for JSON payload to avoid encoding issues
    TEMP_JSON=$(mktemp)
    cat > "$TEMP_JSON" <<EOF
{
    "properties": {
        "value": $(echo "$POLICY_CONTENT" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))"),
        "format": "rawxml"
    }
}
EOF

    # Apply policy using Azure REST API
    POLICY_URL="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_SERVICE/apis/$API_ID/operations/$operation_id/policies/policy?api-version=2022-08-01"

    echo -e "  ${GRAY}Applying JWT validation policy...${NC}"

    ERROR_OUTPUT=$(az rest --method put --url "$POLICY_URL" --body "@$TEMP_JSON" 2>&1)
    EXIT_CODE=$?

    # Clean up temp file
    rm -f "$TEMP_JSON"

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "  ${GREEN}✓ Policy applied successfully${NC}"
        echo ""
        return 0
    else
        echo -e "  ${RED}✗ Policy application failed${NC}"
        echo -e "  ${RED}Error: $ERROR_OUTPUT${NC}"
        echo ""
        return 1
    fi
}

# Process operations requiring JWT
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}Processing Operations${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

for operation in "${OPERATIONS_WITH_JWT[@]}"; do
    if apply_policy "$operation"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
done

# Report on public operations
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}Public Operations (No JWT Required)${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

for operation in "${PUBLIC_OPERATIONS[@]}"; do
    echo -e "${GRAY}Skipping operation: $operation${NC}"
    echo -e "  ${GRAY}Type: Public/All tiers (no JWT validation)${NC}"
    echo -e "  ${GREEN}✓ No changes needed${NC}"
    echo ""
    ((SKIP_COUNT++))
done

# Summary
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}Summary${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${GREEN}JWT policies applied:  $SUCCESS_COUNT${NC}"
echo -e "${GRAY}Operations skipped:    $SKIP_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Failures:              $FAIL_COUNT${NC}"
else
    echo -e "${GRAY}Failures:              $FAIL_COUNT${NC}"
fi
echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${MAGENTA}[DRY RUN MODE] No changes were made${NC}"
    echo -e "${MAGENTA}Run without DRY_RUN=true to apply changes${NC}"
else
    echo -e "${GREEN}Deployment complete!${NC}"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test JWT validation on Premium/Pro operations"
echo "2. Verify public operations still work without JWT"
echo "3. Update mobile app to include JWT tokens in requests"
echo ""

# Exit with error if there were failures
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi

exit 0
