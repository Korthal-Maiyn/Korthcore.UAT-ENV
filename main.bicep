// Deployment parameters
@description('Location to deploy all resources. Inherits from the parent resource group location.')
param location string = resourceGroup().location

@description('The Environment in which these resources are to be deployed.')
@allowed([
  'dev'
  'test'
  'stag'
  'prod'
])
param env string

@description('The resource specific tags Object from the Parameters file.')
param resourceTags object

@description('The date in which the Resource was deployed. In UTC yyyy-MM-dd format.')
param deploymentDate string = utcNow('yyyy-MM-dd')

// Virtual network parameters
@description('Name for the virtual network.')
param virtualNetworkName string = ''

@description('Address space for the virtual network, in IPv4 CIDR notation.')
param virtualNetworkAddressSpace string = '10.0.0.0/16'

@description('Name for the default subnet in the virtual network.')
param subnetName string = ''

@description('Address range for the default subnet, in IPv4 CIDR notation.')
param subnetAddressRange string = '10.0.0.0/24'

@description('Public IP address of your local machine, in IPv4 CIDR notation. Used to restrict remote access to resources within the virtual network.')
param allowedSourceIPAddress string = '' // Home Public IP. 

// Storage Account Parameters
@description('The SAS token for the Deploy-DomainServices.ps1.zip DSC File.')
@secure()
param domainServicesSasToken string

// @description('The SAS token for the Join-Domain.ps1.zip DSC File.')
@secure()
param joinDomainSasToken string

// Virtual machine parameters
@description('Name for the domain controller virtual machine.')
param domainControllerName string = ''

// @description('Name for the workstation virtual machine.')
param workstationName string = ''

@description('Size for both the domain controller and workstation virtual machines.')
@allowed([
  'Standard_B2s' // Generic low burstable VM size for DC and Workstation VMs. Add additional as required.
  'Standard_DS2_v2' // Suggested size for Domain Controller. See https://stackoverflow.com/questions/61985840/arm-template-with-dsc-extension-fails-with-security-error-after-reboot-during-cr
])
param virtualMachineSize string = 'Standard_B2s'

// Domain parameters
@description('FQDN for the Active Directory domain.')
@minLength(3)
@maxLength(255)
param domainFQDN string = ''

@description('Administrator username for both the domain controller and workstation virtual machines.')
@minLength(1)
@maxLength(20)
param adminUsername string = ''

@description('Administrator password for both the domain controller and workstation virtual machines.')
@secure()
param adminPassword string

// Configure Default Tags
module tags 'modules/conventions/tagging.bicep' = {
  name: 'tagging'
  params: {
    region: location
    environment: env
    deploymentDate: deploymentDate
  }
}

// Deploy the virtual network
module virtualNetwork 'modules/network.bicep' = {
  name: 'virtualNetwork'
  params: {
    location: location
    tags: tags.outputs.tags
    resourceTags: resourceTags
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
  }
}

// Deploy the domain controller
module domainController 'modules/vm.bicep' = {
  name: 'domainController'
  params: {
    location: location
    tags: tags.outputs.tags
    resourceTags: resourceTags
    subnetId: virtualNetwork.outputs.subnetId
    vmName: domainControllerName
    vmSize: virtualMachineSize
    vmPublisher: 'MicrosoftWindowsServer'
    vmOffer: 'WindowsServer'
    vmSku: '2019-Datacenter'
    vmVersion: 'latest'
    vmStorageAccountType: 'StandardSSD_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Use PowerShell DSC to deploy Active Directory Domain Services on the Domain Controller
resource domainControllerConfiguration 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${domainControllerName}/Microsoft.Powershell.DSC'
  dependsOn: [
    domainController
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      WmfVersion: 'latest'
      configuration: {
        url: 'https://stsfl001.blob.${environment().suffixes.storage}/dsc-configurations/Deploy-DomainServices.ps1.zip?'
        script: 'Deploy-DomainServices.ps1'
        function: 'Deploy-DomainServices'
      }
      configurationArguments: {
        domainFQDN: domainFQDN
        adminCredential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      configurationUrlSasToken: domainServicesSasToken
      Items: {
          adminPassword: adminPassword
      }
    }
  }
}

// Update the virtual network with the domain controller as the primary DNS server
module virtualNetworkDNS 'modules/network.bicep' = {
  name: 'virtualNetworkDNS'
  dependsOn: [
    domainControllerConfiguration
  ]
  params: {
    location: location
    tags: tags.outputs.tags
    resourceTags: resourceTags
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
    dnsServerIPAddress: domainController.outputs.privateIpAddress
  }
}

// Deploy the workstation once the virtual network's primary DNS server has been updated to the domain controller
module workstation 'modules/vm.bicep' = {
  name: 'workstation'
  dependsOn: [
    virtualNetworkDNS
  ]
  params: {
    location: location
    tags: tags.outputs.tags
    resourceTags: resourceTags
    subnetId: virtualNetwork.outputs.subnetId
    vmName: workstationName
    vmSize: virtualMachineSize
    vmPublisher: 'MicrosoftWindowsDesktop'
    vmOffer: 'Windows-11'
    vmSku: 'win11-22h2-ent'
    vmVersion: 'latest'
    vmStorageAccountType: 'StandardSSD_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// // Use PowerShell DSC to join the workstation to the domain
resource workstationConfiguration 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${workstationName}/Microsoft.Powershell.DSC'
  dependsOn: [
    workstation
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: 'https://stsfl001.blob.${environment().suffixes.storage}/dsc-configurations/Join-Domain.ps1.zip?'
        script: 'Join-Domain.ps1'
        function: 'Join-Domain'
      }
      configurationArguments: {
        domainFQDN: domainFQDN
        computerName: workstationName
        adminCredential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      configurationUrlSasToken: joinDomainSasToken
      Items: {
          adminPassword: adminPassword
      }
    }
  }
}
