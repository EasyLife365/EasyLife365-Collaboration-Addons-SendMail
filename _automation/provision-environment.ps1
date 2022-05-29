### This script requires the Azure CLI. Download it here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
# 
# Create a resources-STAGENAME.json file under _automation/config or edit the existing file resources-dev.json.
# Pass the name of the stage and the target subscription Id for the deployment as parameters
#
# Example: ./_automation/provision-environment.ps1 -stage dev -subscriptionId 299d79b8-827b-490b-8a58-6cc8149f4d29
#
###

param(
    $subscriptionId = '00000000-0000-0000-0000-000000000000',
    $stage = 'dev'
)
# login to azure cli and set subscription
$null = az login
az account set --subscription $subscriptionId

# change to this repositories root folder and run provision.ps1
$root = git rev-parse --show-toplevel
Set-Location $root
./_automation/provision.ps1 $stage