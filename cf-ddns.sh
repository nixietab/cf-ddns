#!/bin/bash

BASE_URL="https://api.cloudflare.com/client/v4"

# Color setup
red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
cyan()   { echo -e "\033[36m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }
log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }


usage() {
  bold "Usage: $0 -z <zone_id> -t <api_token>"
  echo ""
  cyan "Options:"
  echo "  $(green '-z, --zone-id')   Cloudflare Zone ID"
  echo "  $(green '-t, --token')     Cloudflare API Token"
  echo "  $(green '-h, --help')      Show this help message"
  echo ""
  yellow "NOTE: Make sure the API token has DNS Zone permissions (Zone > DNS > Edit)."
  exit 1
}

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zone-id) CF_ZONE_ID="$2"; shift 2 ;;
    -t|--token)   CF_API_TOKEN="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *) red "Unknown argument: $1"; usage ;;
  esac
done

# Validation
if [[ -z "$CF_ZONE_ID" ]]; then
  red "Error: Zone ID is required. Use -z."
  usage
fi
if [[ -z "$CF_API_TOKEN" ]]; then
  red "Error: API token is required. Use -t."
  usage
fi

# Check depent
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    red "Error: '$cmd' is required but not installed."
    exit 1
  fi
done

# Resolve current public IP using ipify, falling back to icanhazip
log "Fetching current external IP..."
CURRENT_IP=$(curl -s https://api4.ipify.org || curl -s https://ipv4.icanhazip.com)
if [[ -z "$CURRENT_IP" || ! "$CURRENT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  red "Failed to get external IP."
  exit 1
fi
log "External IP: $CURRENT_IP"

# Fetch all A records for the given zone from the Cloudflare API
RESPONSE=$(curl -s -X GET \
  "$BASE_URL/zones/$CF_ZONE_ID/dns_records?type=A&per_page=100" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [[ "$SUCCESS" != "true" ]]; then
  red "Failed to fetch DNS records:"
  echo "$RESPONSE" | jq '.errors'
  exit 1
fi

RECORDS=$(echo "$RESPONSE" | jq -c '.result[]')
COUNT=$(echo "$RESPONSE" | jq '.result | length')

if [[ "$COUNT" -eq 0 ]]; then
  yellow "No A records found in zone."
  exit 0
fi

# Loop through each A record and update it if the IP has changed
UPDATED=0
SKIPPED=0
while IFS= read -r record; do
  RECORD_ID=$(echo "$record" | jq -r '.id')
  RECORD_NAME=$(echo "$record" | jq -r '.name')
  RECORD_IP=$(echo "$record" | jq -r '.content')
  RECORD_PROXIED=$(echo "$record" | jq -r '.proxied')
  RECORD_TTL=$(echo "$record" | jq -r '.ttl')

  # Skip records that already point to the current IP
  if [[ "$RECORD_IP" == "$CURRENT_IP" ]]; then
    log "$(yellow "SKIP") $RECORD_NAME (already $CURRENT_IP)"
    ((SKIPPED++))
    continue
  fi

  # Send a PATCH request to update the record content to the current IP
  log "UPDATE $RECORD_NAME ($RECORD_IP -> $CURRENT_IP)"
  UPDATE_RESPONSE=$(curl -s -X PATCH \
    "$BASE_URL/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"content\": \"$CURRENT_IP\"}")

  UPDATE_SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
  if [[ "$UPDATE_SUCCESS" == "true" ]]; then
    green "  OK $RECORD_NAME updated"
    ((UPDATED++))
  else
    red "  FAILED $RECORD_NAME:"
    echo "$UPDATE_RESPONSE" | jq '.errors'
  fi
done <<< "$RECORDS"

# Summary
echo ""
log "Done. Updated: $UPDATED, Skipped (no change): $SKIPPED"