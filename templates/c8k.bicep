param ck8name string
param vnetname string
param insideSubnetid string
param outsideSubnetid string
param prefixId string
param udrName string
param adminUsername string
param adminPassword string

resource pubip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: '${ck8name}-pubip'
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
resource insidenic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-insidenic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: insideSubnetid
          }
          primary: true
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}
resource outsidenic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-outsidenic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: outsideSubnetid
          }
          publicIPAddress: {
            id: pubip.id
          }
          primary: true
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}
resource ck8 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: ck8name
  location: resourceGroup().location
  plan: {
    publisher: 'cisco'
    name: '17_15_01a-byol'
    product: 'cisco-c8000v-byol'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-c8000v-byol'
        sku: '17_15_01a-byol'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: ck8name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: insidenic.id
          properties: {
            primary: false
          }
        }
        {
          id: outsidenic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}
resource route 'Microsoft.Network/routeTables/routes@2020-11-01' = {
  name: '${udrName}/route1'
  dependsOn: [
    ck8
  ]
  properties: {
    addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: insidenic.properties.ipConfigurations[0].properties.privateIPAddress
        }
}
