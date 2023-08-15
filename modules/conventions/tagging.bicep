param region string
param environment string
param deploymentDate string

var tagsObject = {
  Region: region
  Environment: environment
  DeploymentDate: deploymentDate
}

output tags object = tagsObject
