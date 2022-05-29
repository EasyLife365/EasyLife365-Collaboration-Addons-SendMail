param location string = resourceGroup().location
param stage string
param resourceNamesPrefix string
param applicationName string
param workspaceId string
param functionName string
param mailFromAddress string
param mailToAddresses string

var storageAccountName = '${resourceNamesPrefix}${applicationName}${stage}st'
var hostingPlanName = '${resourceNamesPrefix}-${applicationName}-${stage}-ap'
var appInsightsName = '${resourceNamesPrefix}-${applicationName}-${stage}-ai'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: replace(storageAccountName, '-', '')
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: workspaceId
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
    'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionName}': 'Resource'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
    siteConfig: {
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'powershell'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'mailFromAddress'
          value: mailFromAddress
        }
        {
          name: 'mailToAddresses'
          value: mailToAddresses
        }
      ]
    }
  }
}

output functionPrincipalId string = functionApp.identity.principalId
output functionName string = functionApp.name
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output storageaccountApiVersion string  = storageAccount.apiVersion
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
