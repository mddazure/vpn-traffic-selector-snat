resource prefix 'Microsoft.Network/publicIPPrefixes@2020-11-01' = {
  name: 'prefix'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  zones:[
    '1'
    '2'
    '3'
  ]
  properties: {
    prefixLength: 29
    publicIPAddressVersion: 'IPv4'

  }
}

output prefixId string = prefix.id
