param customerPip string
param providerPip string

resource nsg  'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'outsidensg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Allow-VPN-in'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            customerPip
            providerPip
          ]                  
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
output nsgId string = nsg.id
