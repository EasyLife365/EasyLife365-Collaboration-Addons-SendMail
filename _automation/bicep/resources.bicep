param stage string
param applicationName string
param resourceNamesPrefix string
param location string = resourceGroup().location

module logAnalyticsModule 'loganalyticsWorkspace.bicep' = {
  name: 'logAnalyticsModule'
  params: {
    name: '${resourceNamesPrefix}-${applicationName}-${stage}-la'
    location: location
  }
}

var functionName = '${resourceNamesPrefix}-${applicationName}-${stage}-fa'
module functionAppModule 'functionApp.bicep' = {
  name: 'functionAppModule'
  dependsOn: [
    logAnalyticsModule
  ]
  params: {
    functionName: functionName
    stage: stage
    resourceNamesPrefix: resourceNamesPrefix
    applicationName: applicationName
    location: location
    workspaceId: logAnalyticsModule.outputs.logAnalyticsWorkspaceID
  }
}

output functionName string = functionName
