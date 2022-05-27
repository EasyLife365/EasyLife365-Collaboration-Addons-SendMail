### This script requires the Azure CLI. Download it here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

az login

# Create or configure a resources-STAGENAME.json file under _automation/config
$stage = "dev"
# Put the target subscription Id for the deployment
$subscriptionId = "<putYourSubscriptionIdHere>"

$root = git rev-parse --show-toplevel
Set-Location $root

az account set --subscription $subscriptionId

./_automation/provision.ps1 $stage