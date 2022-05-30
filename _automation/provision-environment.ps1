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
$output = ./_automation/provision.ps1 $stage


# take the last output from provision.ps1 and assign graph API permissions
# you need to be signed in with an account with the global admin role.

$servicePrincipalId = $output[-1]
$graphObjectId = (az ad sp list --display-name 'Microsoft Graph' | ConvertFrom-Json)[0].objectId

# assign permissions to the managed identity
@(
    'df021288-bdef-4463-88db-98f22de89214', # user.read.all
    '5b567255-7703-4780-807c-7be8301ae99b', # group.read.all 
    'b633e1c5-b582-4048-a93e-9f11b44c7e96'  # mail.send
) | ForEach-Object{
    $body = @{
        principalId = $servicePrincipalId
        resourceId = $graphObjectId
        appRoleId = $_
    } | ConvertTo-Json -Compress
    $uri = "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignments"
    $header = "Content-Type=application/json"
    # for some reason, the body must only use single quotes
    az rest --method POST --uri $uri --header $header --body $body.Replace('"',"'") | ConvertFrom-Json
}