using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Write-Host "HTTP trigger function processed a request of type: $($Request.eventType)."

$Request
"---"
$TriggerMetadata

# add request to queue
Push-OutputBinding -Name queueItem -Value $Request

# Respond to webhook with 200 ok
Push-OutputBinding -Name Response -Value (
    [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
    }
)
