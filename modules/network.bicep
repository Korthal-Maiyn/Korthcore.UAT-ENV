// Deployment Params
param location string
param tags object = {}
param resourceTags object = {}
// Resource Params
param virtualNetworkName string
param virtualNetworkAddressSpace string
param subnetName string
param subnetAddressRange string
param allowedSourceIPAddress string
param dnsServerIPAddress string = ''

// Create a network security group to restrict remote access to resources within the virtual network
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-sfl-rdp'
  location: location
  tags: union(tags, resourceTags.nsg)
  properties: {
    securityRules: [
      {
        name: 'allow-inbound-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: allowedSourceIPAddress
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Deploy the virtual network and a default subnet associated with the network security group
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: virtualNetworkName
  location: location
  tags: union(tags, resourceTags.vnet)
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressSpace
      ]
    }
    dhcpOptions: {
      dnsServers: ((!empty(dnsServerIPAddress)) ? array(dnsServerIPAddress) : null)
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressRange
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output subnetId string = vnet.properties.subnets[0].id
