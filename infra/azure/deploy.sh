#!/usr/bin/env bash
set -euo pipefail

trap 'rm -f parameters.json' EXIT

# Required environment variables:
# - AZURE_SUBSCRIPTION_ID
# - AZURE_RESOURCE_GROUP
# - AZURE_NAME_PREFIX
# - AZURE_ENVIRONMENT
# - AZURE_SQL_LOGIN
# - AZURE_SQL_AD_LOGIN
# - AZURE_SQL_AD_OBJECTID
# - SQL_ADMIN_PASSWORD
# - KV_ACCESS_JSON (JSON array, defaults to [])
# Optional:
# - AZURE_LOCATION

if [[ -z "${SQL_ADMIN_PASSWORD:-}" ]]; then
  echo "AZURE_SQL_ADMIN_PASSWORD secret is not set." >&2
  exit 1
fi

kv_access_json="${KV_ACCESS_JSON:-[]}" 
cat > parameters.json <<EOF
{
  "namePrefix": {
    "value": "${AZURE_NAME_PREFIX}"
  },
  "environment": {
    "value": "${AZURE_ENVIRONMENT}"
  },
  "sqlAdministratorLogin": {
    "value": "${AZURE_SQL_LOGIN}"
  },
  "sqlAdministratorPassword": {
    "value": "${SQL_ADMIN_PASSWORD}"
  },
  "sqlAdAdminLogin": {
    "value": "${AZURE_SQL_AD_LOGIN}"
  },
  "sqlAdAdminObjectId": {
    "value": "${AZURE_SQL_AD_OBJECTID}"
  },
  "keyVaultAccessObjectIds": {
    "value": ${kv_access_json}
  }
}
EOF

if [[ -n "${AZURE_LOCATION:-}" ]]; then
  az deployment group create \
    --subscription "${AZURE_SUBSCRIPTION_ID}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --template-file main.bicep \
    --parameters @parameters.json location="${AZURE_LOCATION}"
else
  az deployment group create \
    --subscription "${AZURE_SUBSCRIPTION_ID}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --template-file main.bicep \
    --parameters @parameters.json
fi
