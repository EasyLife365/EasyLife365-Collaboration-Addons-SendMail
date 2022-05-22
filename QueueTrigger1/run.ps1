# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message to the information log.
Write-Host "PowerShell queue trigger function processed work item: $($QueueItem | ConvertTo-Json -Depth 6 -Compress)"

# import modules, az.accounts is used to obtain a token for mgGraph
Import-Module Az.Accounts, Microsoft.Graph.Users.Actions

$Token = Get-AzToken -ResourceUri 'https://graph.microsoft.com/'
Connect-MgGraph -AccessToken $Token

$group = Get-MgGroup -GroupId $QueueItem.Body.group.id 
$groupOwners = (Get-MgGroupOwner -GroupId $QueueItem.Body.group.id).AdditionalProperties

$mailText = @"
EasyLife created a new $($group.Visibility) Team with the name: $($QueueItem.Body.group.displayName).

The team was created by: $($QueueItem.Body.user.userPrincipalName).
The team's owners are: $($groupOwners.userPrincipalName -join ', ').

Thanks for using EasyLife!
"@

$mailParams = @{
	Message = @{
		Subject = "New team: $($QueueItem.Body.group.displayName)"
		Body = @{
			ContentType = "Text"
			Content = $mailText
		}
		ToRecipients = @()
		CcRecipients = @()
	}
	SaveToSentItems = "false"
}

# support multiple recipients in a space-separated string
$env:mailToAddresses -split ' ' | Where-Object {$_ -match "@"} | ForEach-Object {
    $mailParams.Message.ToRecipients += @{EmailAddress = @{Address = $_}}
}

# A UPN can also be used as -UserId
if($env:fromAddr -match "@"){
    $userId = $env:mailFromAddress
} else {
    $userId = $QueueItem.Body.user.userPrincipalName
}

Write-Host "Sending from [$userId] with params: [$($mailParams | ConvertTo-Json -Depth 6 -Compress)]"
Send-MgUserMail -UserId $userId -BodyParameter $mailParams
