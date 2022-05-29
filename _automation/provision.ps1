param (
    [Parameter(Mandatory=$true)]
    [string]$stage
)

$root = git rev-parse --show-toplevel
Set-Location $root

$configFile = "./_automation/config/resources-$stage.json"
$config = get-content $configFile | ConvertFrom-Json
$rgname = "rg-$($config.parameters.resourceNamesPrefix.value)-$($config.parameters.applicationName.value)-$($config.parameters.stage.value)"

az group create -n $rgname --location $config.parameters.location.value | ConvertFrom-Json

# deploy the bicep file
$output = az deployment group create `
    --resource-group $rgname `
    --template-file "./_automation/bicep/resources.bicep" `
    --parameters $configFile | ConvertFrom-Json

$deployPath = Get-ChildItem | `
    Where-Object {$_.Name -notmatch "deploypkg" -and $_.Name -notmatch "_automation" } | `
    Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru
    
az functionapp deployment source config-zip `
    --name $output.properties.outputs.functionName.value `
    --resource-group $rgname `
    --src $deployPath.FullName | ConvertFrom-Json

$graphObjectId = (az ad sp list --display-name 'Microsoft Graph' | ConvertFrom-Json)[0].objectId
$servicePrincipalId = $output.properties.outputs.functionPrincipalId.value

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
