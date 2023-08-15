// Deployment Params
param location string
param tags object = {}
param resourceTags object = {}
// Resource Params
param subnetId string
param vmName string
param vmSize string
param vmPublisher string
param vmOffer string
param vmSku string
param vmVersion string
param vmStorageAccountType string
param adminUsername string
@secure()
param adminPassword string

// Create the virtual machine's public IP address
resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: 'pip-${vmName}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')
    }
  }
}

// Create the virtual machine's NIC and associate it with the applicable public IP address and subnet
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic-01-${vmName}'
  location: location
  tags: union(tags, resourceTags.nic)
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// Deploy the virtual machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: union(tags, resourceTags.vm)
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmPublisher
        offer: vmOffer
        sku: vmSku
        version: vmVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: vmStorageAccountType
        }
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  // Install the Azure Monitor Agent
  resource ama 'extensions@2023-03-01' = {
    name: 'AzureMonitorWindowsAgent'
    location: location
    properties: {
      publisher: 'Microsoft.Azure.Monitor'
      type: 'AzureMonitorWindowsAgent'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
    }
  }
}

output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output fqdn string = pip.properties.dnsSettings.fqdn
