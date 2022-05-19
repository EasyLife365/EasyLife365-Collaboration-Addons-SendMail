using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$request.body | Push-OutputBinding $outputQueueItem

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value (
    [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
    }
)
