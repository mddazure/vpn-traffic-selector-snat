param vnetname string
param vnetIPrange string
param outsideSubnetIPrange string
param insideSubnetIPrange string
param vmSubnetIPrange string
param c8kpipName string
param prefixId string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetname
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIPrange
      ]
    }
  }
}
resource outsideSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'outside'
  properties: {
    addressPrefix: outsideSubnetIPrange
  }
}
resource insideSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'inside'
  dependsOn: [
    outsideSubnet
  ]
  properties: {
    addressPrefix: insideSubnetIPrange
  }
}
resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  dependsOn: [
    insideSubnet
  ]
  name: 'vm'
  properties: {
    addressPrefix: vmSubnetIPrange
    routeTable: {
      id: udr.id
    }
  }
}
resource pubip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: c8kpipName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'    
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
  publicIPPrefix: {
      id: prefixId
    }
   publicIPAllocationMethod: 'Static'
   publicIPAddressVersion: 'IPv4'
  }
}
resource udr 'Microsoft.Network/routeTables@2020-11-01' = {
  name: '${vnetname}-udr'
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: false
  }
}

output vnetName string = vnet.name
output udrId string = udr.id
output udrName string = udr.name
output vnetId string = vnet.id
output outsideSubnetId string = outsideSubnet.id
output insideSubnetId string = insideSubnet.id
output vmSubnetId string = vmSubnet.id
output pubIp string = pubip.properties.ipAddress
output pubipId string = pubip.id
