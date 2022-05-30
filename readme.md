# Use Azure Functions to run custom PowerShell code with EasyLife

This is a sample Azure Function that shows how EasyLife's webhook feature can be used to extend the product with custom code. In this example, we use the Microsoft Graph PowerShell module to send an email notification to an address that is specified in the Function App's configuration.

The app uses two functions:

- mailrequest: This function uses a http trigger. The function simply writes any request that it receives to a storage queue.
- mailqueue: This function uses a queue trigger. When the mailrequest function writes a new item to the storage queue, this function is started and the content of the request is available as parameter.

The app can be deployed using PowerShell with Azure CLI or with Bicep. In both cases you need to install the Azure CLI, which you can find here: [https://aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows).

## Deploy the solution to an Azure Subscription via PowerShell

You can use the following PowerShell and Azure CLI code to deploy the solution to an Azure subscription. Update the values of variables in the first few lines to match your requirements, then run the whole thing in a PowerShell session.

```powershell
# edit parameters
# specify the name and location of the resources that will be created 
$resourceGroupName = "el-sendmail1"
$functionAppName = "el-sendmail1"
$storageAccountName = "elsendmail001"
$location = "westeurope"
# specify one from address for the notification emails, if not defined (""), the address of the requestor will be used
$mailFromAddress = "notification@example.com"
# specify one or more recipient addresses in a space-separated list
$mailToAddresses = "user1@example.com user2@example.com"

# login to azure and optionally change subscription
az login
# az account set --subscription 00000000-0000-0000-0000-000000000000

# there should be no need to change anything below this

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
    Where-Object {$_.Name -notmatch "deploypkg" -and $_.Name -notmatch "_automation" } | `
    Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru

# deploy the zipped package
az functionapp deployment source config-zip `
    --name $functionAppName `
    --resource-group $resourceGroupName `
    --src $deployPath.FullName
```

## Deploy the solution to an Azure Subscription via Bicep

You can also use Azure Bicep to deploy the solution. You can find the script to start the deployment from localhost under `_automation/provisioning-environment.ps1`. You can use the script `_automation/provision.ps1` in a GitHub action after signing in to Azure AD with a service principal. We provide two sample parameter files for the Bicep script under `_automation/config`.

Before you start a new deployment, you need to make a few changes to the config files mentioned below. We recommend you [fork](https://github.com/EasyLife365/EasyLife365-Addon-SendMail/generate) the repository and change the values in your fork.

- resources-dev.json and resources-prod.json:
  - Adjust the values of the following settings to match your requirements:
    - applicationName
    - resourceNamesPrefix
    - location
    - mailFromAddress
    - mailToAddresses

After saving the changes, you can start the deployment by running `_automation/provisioning-environment.ps1` either locally or as GitHub action. You can enter the subscription id you want to use as default parameter or pass it on execution like in the following example:

```powershell
# this example will prompt you to login to Azure and then start the provisioning for the dev stage in the
# given subscription id. The default stage is dev. 
./_automation/provisioning-environment.ps1 -subscriptionId 7e683c0d-6c0c-4e7f-b2c1-b8fe837ba82a

# this example provisions the prod stage
./_automation/provisioning-environment.ps1 -stage prod -subscriptionId 7e683c0d-6c0c-4e7f-b2c1-b8fe837ba82a
```

## Test the function app

Once you have deployed the function to Azure, you are ready for testing. You need to get the function URL from the Azure Portal. To find the function URL, open the function app in the Azure Portal. Then click *Functions* in the left-hand navigation and click the *mailrequest* function to open its properties. In the *Overview* tab, click *Get Function URL* and copy the URL.
It will look like this example: `https://<appName>.azurewebsites.net/api/HttpTrigger1?code=<code>`

This is the URL that you want use as webhook in the EasyLife configuration, but before setting the webhook url in EasyLife, make sure to run the function app at least once. The first execution is slow as requirements defined in `requirements.psd1` are installed.

You can use the following PowerShell snippet to run the function app. Make sure to update the `$uri` variable with your function URL and insert the object id of a group in your tenant as `group.id`:

```powershell
$uri = 'https://<functionAppName>.azurewebsites.net/api/mailrequest?code=<code>'
$item = @{
    eventType = "groupcreated"
    user = @{
        userPrincipalName = "testuser@example.com"
    }
    group = @{
        displayName = "Test Team Name"
        id = "00000000-0000-0000-0000-000000000000" # should exist in tenant for valid test
    }
}
Invoke-RestMethod -Uri $uri -Body ($item | ConvertTo-Json -Compress) -Method Post
```

For more information please see: [docs.easylife365.cloud](https://docs.easylife365.cloud)
