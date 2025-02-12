param location string = 'swedencentral'
param rgname string = 'vpn-lab-rg'
param customerVnetName string = 'client-Vnet'
param customerVnetIPrange string = '10.0.0.0/16'
param customerOutsideSubnetIPrange string = '10.0.0.0/24'
param customerInsideSubnetIPrange string = '10.0.1.0/24'
param customerVmSubnetIPrange string = '10.0.2.0/24'
param customerVmName string = 'client-Vm'
param customerC8kName string = 'c8k-0'
param customerPipName string = 'c8k-0-pip'
param providerVnetName string = 'provider-Vnet'
param providerVnetIPrange string = '10.10.0.0/16'
param providerOutsideSubnetIPrange string = '10.10.0.0/24'
param providerInsideSubnetIPrange string = '10.10.1.0/24'
param providerVmSubnetIPrange string = '10.10.2.0/24'
param providerVmName string = 'provider-Vm'
param providerC8kName string = 'c8k-10'
param providerPipName string = 'c8k-10-pip'

param adminUsername string = 'AzureAdmin'
param adminPassword string = 'vpn@123456'


targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgname
  location: location
}

module prefix 'prefix.bicep' = {
  name: 'prefix'
  scope: rg
}

module customerVnet 'vnet.bicep' = {
  name: 'customerVnet'
  scope: rg
  params: {
    vnetname: customerVnetName
    vnetIPrange: customerVnetIPrange
    outsideSubnetIPrange: customerOutsideSubnetIPrange
    insideSubnetIPrange: customerInsideSubnetIPrange
    vmSubnetIPrange: customerVmSubnetIPrange
    prefixId: prefix.outputs.prefixId
    c8kpipName: customerPipName
  }
}
module providerVnet 'vnet.bicep' = {
  name: 'providerVnet'
  scope: rg
  params: {
    vnetname: providerVnetName
    vnetIPrange: providerVnetIPrange
    outsideSubnetIPrange: providerOutsideSubnetIPrange
    insideSubnetIPrange: providerInsideSubnetIPrange
    vmSubnetIPrange: providerVmSubnetIPrange
    c8kpipName: providerPipName
    prefixId: prefix.outputs.prefixId
  }
}
module outsideNsg 'nsg.bicep' = {
  name: 'outsideNsg'
  scope: rg
  params: {
    customerPip: customerVnet.outputs.pubIp
    providerPip: providerVnet.outputs.pubIp
  }
}
module customerVm 'vm.bicep' = {
  name: 'customerVm'
  scope: rg

  params: {
    vmname: customerVmName
    subnetId: customerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerVm 'vm.bicep' = {
  name: 'providerVm'
  scope: rg
  params: {
    vmname: providerVmName
    subnetId: providerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module customerC8k 'c8k.bicep' = {
  name: 'customerC8k'
  scope: rg
  params: {
    ck8name: customerC8kName
    vnetname: customerVnet.outputs.vnetId
    insideSubnetid: customerVnet.outputs.insideSubnetId
    outsideSubnetid: customerVnet.outputs.outsideSubnetId
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: customerVnet.outputs.pubipId
    udrName: customerVnet.outputs.udrName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerC8k 'c8k.bicep' = {
  name: 'providerC8k'
  scope: rg
  params: {
    ck8name: providerC8kName
    vnetname: providerVnet.outputs.vnetId
    insideSubnetid: providerVnet.outputs.insideSubnetId
    outsideSubnetid: providerVnet.outputs.outsideSubnetId
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: providerVnet.outputs.pubipId
    udrName: providerVnet.outputs.udrName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

