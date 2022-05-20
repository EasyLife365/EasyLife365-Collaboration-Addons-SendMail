# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"

Import-Module Az.Accounts, Microsoft.Graph.Users.Actions

$Token = Get-AzToken -ResourceUri 'https://graph.microsoft.com/'
Connect-MgGraph -AccessToken $Token

$item = $QueueItem.Body

$mgGroup = Get-MgGroup -GroupId $item.group.id -ExpandProperty Owners

$mailText = @"
EasyLife created a new $($mgGroup.Visibility) Team with the name: $($item.group.displayName).

The team was created by: $($item.user.userPrincipalName).
The team's owners are: $($mgGroup.Owners.AdditionalProperties.displayName -join ', ').

Thanks for using EasyLife!
"@

$mailParams = @{
	Message = @{
		Subject = "New team: $($item.group.displayName)"
		Body = @{
			ContentType = "Text"
			Content = $mailText
		}
		ToRecipients = @(
			@{
				EmailAddress = @{
					Address = $env:recipient
				}
			}
		)
		CcRecipients = @()
	}
	SaveToSentItems = "false"
}

# A UPN can also be used as -UserId
if($env:fromAddr -match "@"){
    $userId = $env:fromAddr
} else {
    $userId = $item.user.userPrincipalName
}

Write-Host "Sending from [$userId] with params: [$($mailParams | ConvertTo-Json -Depth 6 -Compress)]"
Send-MgUserMail -UserId $userId -BodyParameter $mailParams
