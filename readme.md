# grant permissions

```powershell
# requires az cli
az login

# enterprise app object id
$servicePrincipalId = "cbd11a95-412d-475f-963d-1d37c9742e9b"
$subscriptionId = "1e5b205a-ead1-4afb-99d2-335f45260e53"

az account set --subscription $subscriptionId

$graphObjectId = $(az ad sp list --query "[?appDisplayName=='Microsoft Graph'].objectId | [0]" --all --out tsv)

# Group.Read.All
$appRole = "{'principalId':'$servicePrincipalId','resourceId':'$graphObjectId','appRoleId':'5b567255-7703-4780-807c-7be8301ae99b'}"
az rest --method POST --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignments" --header "Content-Type=application/json" --body $appRole

# Mail.Send
$appRole = "{'principalId':'$servicePrincipalId','resourceId':'$graphObjectId','appRoleId':'b633e1c5-b582-4048-a93e-9f11b44c7e96'}"
az rest --method POST --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignments" --header "Content-Type=application/json" --body $appRole
```

# test 

```powershell
$uri = 'https://elsendmail1.azurewebsites.net/api/HttpTrigger1?code=tipYzqAGNN1m2FUoon5heFhbSfiSGnS4fNOvWIgPM69VAzFuGaEWww=='

$item = @{
    user = @{
        userPrincipalName = "tom@uclab.eu"
    }
    group = @{
        displayName = "testing123"
    }
} 

Invoke-RestMethod -Uri $uri -Body ($item | ConvertTo-Json -Compress)

```
