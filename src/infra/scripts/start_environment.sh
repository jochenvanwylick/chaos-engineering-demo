#!/bin/bash

#######################################################################
# This script ensures the environment is started and ready for (demo) use.
# It will:
# - Enable public network access for all storage accounts
# - Enable local authentication for all CosmosDB accounts
# - Start all AKS clusters
# - Enable public network access for all Key Vaults
#
# Usage:
#   ./start_environment.sh [resource_group_name]
#
# Examples:
#   ./start_environment.sh my-custom-rg     # Use specified resource group
#   ./start_environment.sh                  # Use default (jvwcha-rg)
#######################################################################

# Accept resource group as parameter with default value
RESOURCE_GROUP="${1:-jvwcha-rg}"

echo "🚀 Starting resource updates in $RESOURCE_GROUP..."

# Fetch all storage account names in the resource group and remove carriage returns
echo "📝 Fetching storage accounts..."
storage_accounts=$(az storage account list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" \
  --output tsv | tr -d '\r')
echo "✅ Found $(echo "$storage_accounts" | wc -w) storage accounts"

# Initialize failure counter
FAILURE_COUNT=0

# Loop over each storage account and enable public network access
for account in $storage_accounts; do
  echo "🔄 Enabling public network access for $account..."
  if ! az storage account update --name $account --public-network-access Enabled &>/dev/null; then
    echo "❌ Failed to enable public network access for $account"
    ((FAILURE_COUNT++))
  else
    echo "✅ Public network access enabled"
  fi
done

# Fetch all CosmosDB account names in the resource group
echo "📝 Fetching CosmosDB accounts..."
cosmos_accounts=$(az cosmosdb list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" \
  --output tsv | tr -d '\r')
echo "✅ Found $(echo "$cosmos_accounts" | wc -w) CosmosDB accounts"

# Loop over each CosmosDB account and enable local authentication
for cosmos in $cosmos_accounts; do
  echo "🔄 Enabling local authentication for $cosmos..."
  if ! az resource update \
    --resource-group $RESOURCE_GROUP \
    --name $cosmos \
    --resource-type "Microsoft.DocumentDB/databaseAccounts" \
    --set properties.disableLocalAuth=false &>/dev/null; then
    echo "❌ Failed to enable local authentication for $cosmos"
    ((FAILURE_COUNT++))
  else
    echo "✅ Local authentication enabled"
  fi
done

# Fetch all AKS cluster names in the resource group
echo "📝 Fetching AKS clusters..."
aks_clusters=$(az aks list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" \
  --output tsv | tr -d '\r')
echo "✅ Found $(echo "$aks_clusters" | wc -w) AKS clusters"

# Loop over each AKS cluster and start it
for cluster in $aks_clusters; do
  echo "🔄 Starting AKS cluster $cluster..."
  if ! az aks start \
    --resource-group $RESOURCE_GROUP \
    --name $cluster &>/dev/null; then
    # Check if cluster is already running
    cluster_state=$(az aks show --resource-group $RESOURCE_GROUP --name $cluster --query "powerState.code" -o tsv | tr -d '\r')
    if [ "$cluster_state" = "Running" ]; then
      echo "ℹ️  Cluster $cluster is already running - skipping"
    else
      echo "❌ Failed to start cluster $cluster"
      ((FAILURE_COUNT++))
    fi
  else
    echo "✅ Cluster started"
  fi
done

# Fetch all Key Vault names in the resource group
echo "📝 Fetching Key Vaults..."
key_vaults=$(az keyvault list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" \
  --output tsv | tr -d '\r')
echo "✅ Found $(echo "$key_vaults" | wc -w) Key Vaults"

# Loop over each Key Vault and enable public network access
for vault in $key_vaults; do
  echo "🔄 Enabling network access for $vault..."
  if ! az keyvault update \
    --name $vault \
    --resource-group $RESOURCE_GROUP \
    --default-action Allow \
    --bypass AzureServices &>/dev/null; then
    echo "❌ Failed to enable network access for $vault"
    ((FAILURE_COUNT++))
  else
    echo "✅ Network access enabled"
  fi
done

# Final status report
if [ $FAILURE_COUNT -eq 0 ]; then
  echo "🎉 All resource updates completed successfully in $RESOURCE_GROUP"
else
  echo "⚠️  Resource updates completed with $FAILURE_COUNT failures in $RESOURCE_GROUP"
  echo "📋 Please review the logs above for details on the failed operations"
  exit 1
fi
