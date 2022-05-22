# create azure resources and grant permissions

```powershell
# edit parameters
$resourceGroupName = "el-sendmail1"
$functionAppName = "el-sendmail1"
$storageAccountName = "elsendmail001"
$location = "westeurope"
$mailFromAddress = "notification@example.com"
$mailToAddresses = "user1@example.com user2@example.com"

# login to azure and optionally change subscription
az login
# az account set --subscription 00000000-0000-0000-0000-000000000000

# create resource group
az group create `
--name $resourceGroupName `
--location $location

# create storage account
az storage account create `
--name $storageAccountName `
--resource-group $resourceGroupName `
--location $location `
--sku Standard_LRS

# get connection string for the storage account
$connString = (az storage account show-connection-string -g $resourceGroupName -n $storageAccountName | ConvertFrom-Json).connectionString

# create storage queue with connection string
az storage queue create `
-n queue1 `
--connection-string $connString

# create function app and configure settings
$funcAppOutput = az functionapp create `
--consumption-plan-location $location `
--name $functionAppName --os-type Windows `
--resource-group $resourceGroupName `
--runtime powershell `
--storage-account $storageAccountName `
--functions-version 3 `
--assign-identity '[system]' | ConvertFrom-Json

az functionapp config appsettings set `
--name $functionAppName `
--resource-group $resourceGroupName `
--settings "mailFromAddress=$mailFromAddress"

az functionapp config appsettings set `
--name $functionAppName `
--resource-group $resourceGroupName `
--settings "mailToAddresses=$mailToAddresses"

# get service principals for permission assignment
$servicePrincipalId = $funcAppOutput.identity.principalId
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
    az rest --method POST --uri $uri --header $header --body $body.Replace('"',"'")
}

# update deploy package
$deployPath = Get-ChildItem | `
Where-Object {$_.Name -notmatch "deploypkg"} | `
Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru

# deploy the zipped package
az functionapp deployment source config-zip `
--name $functionAppName `
--resource-group $resourceGroupName `
--src $deployPath.FullName
```

# test the function app

before setting the webhook url in easylife, make sure to ping the function app at least once. The first execution is slow as requirements defined in `requirements.psd1` are installed. Get URI from function app `HTTPTrigger1` and enter a valid group `id`: 

```powershell
$uri = 'https://<functionAppUrl>.azurewebsites.net/api/HttpTrigger1?code=<functionAuthCode>=='

$item = @{
    eventType = "groupcreated"
    user = @{
        userPrincipalName = "testuser@example.com"
    }
    group = @{
        displayName = "Test Team Name"
        id = "bed129c8-2ecb-4cb7-b812-c754270ec7d8" # should exist in tenant for valid test
    }
} 

Invoke-RestMethod -Uri $uri -Body ($item | ConvertTo-Json -Compress)
```
