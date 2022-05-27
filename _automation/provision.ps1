param (
    [Parameter(Mandatory=$true)]
    [string]$stage
)

$root = git rev-parse --show-toplevel
Set-Location $root

$configFile = "./_automation/config/resources-$stage.json"
$config = get-content $configFile | ConvertFrom-Json
$rgname = "rg-$($config.parameters.resourceNamesPrefix.value)-$($config.parameters.applicationName.value)-$($config.parameters.stage.value)"

az group create -n $rgname --location $config.parameters.location.value --verbose

# deploy the bicep file directly
$output = az deployment group create `
    --resource-group $rgname `
    --template-file "./_automation/bicep/resources.bicep" `
    --parameters $configFile | ConvertFrom-Json

$deployPath = Get-ChildItem | `
    Where-Object {$_.Name -notmatch "deploypkg" && $_.Name -notmatch "_automation" } | `
    Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru
    
az functionapp deployment source config-zip `
    --name $output.properties.outputs.functionName.value `
    --resource-group $rgname `
    --src $deployPath.FullName