resource prefix 'Microsoft.Network/publicIPPrefixes@2020-11-01' = {
  name: 'prefix'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    prefixLength: 29
  }
}

output prefixId string = prefix.id
