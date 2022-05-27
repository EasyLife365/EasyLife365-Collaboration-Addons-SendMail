param location string = 'westeurope'
param name string

@allowed([
  'PerGB2018'
])
param sku string = 'PerGB2018'

@minValue(31)
@maxValue(730)
param dataRetentionInDays int = 31

resource logAnalyticsWorkspace_resource 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: dataRetentionInDays
  }
}

output logAnalyticsWorkspaceID string = logAnalyticsWorkspace_resource.id
