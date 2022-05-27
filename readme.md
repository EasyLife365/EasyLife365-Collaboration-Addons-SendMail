# Deploy the solution to an Azure Subscription
The deplyoment is automated with Bicep files. The script to start the deployment from localhost can be found under _automation/provisioning-environment.ps1.
You can also use the _automation/provision.ps1 in a GitHub action after siging in to Azure AD with a service principal.

```powershell
# edit parameters
$resourceGroupName = "el-sendmail1"

# login to azure and optionally change subscription
az login
# az account set --subscription 00000000-0000-0000-0000-000000000000

# create resource group
az group create `
--name $resourceGroupName `
--location $location

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
