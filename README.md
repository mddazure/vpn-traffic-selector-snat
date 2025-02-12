# VPN with Source NAT and Traffic Selector

Some providers of IT services require their customers to connect via VPN tunnels. 

These service providers will usually require their customers to Source NAT to - i.e. hide themselves behind - an IP address from a range they control. This ensures that all customers come in to the provider's environment from unique IP addresses. Providers may also require a custom Traffic Selector matching the Source NAT address, effectively turning the connection into a policy-based rather than a route-based VPN.

Although VPN is an outdated and cumbersome method of connecting to a central service, it is still used in some application fields such as in financial services,  with government agencies, regulatory bodies, tax authorities etc. Customers have no other option than to comply if they want or need to use these provider's services.

Azure customers will usually first attempt to use Azure-native VNET or VWAN VPN Gateways. These Gateways have NAT capabilities and support custom (policy-based) Traffic Selectors, but do ***not*** support combining the two. When this combination is required, the only solution is to use a Network Virtual Appliance (NVA).

See [Comparing Cisco VPN Technologies – Policy Based vs Route Based VPNs](https://www.firewall.cx/cisco/cisco-services-technologies/cisco-comparing-vpn-technologies.html) for an explanation of these concepts from Cisco's persective.

[Connect a VPN gateway to multiple on-premises policy-based VPN devices](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-connect-multiple-policybased-rm-ps) provides an eplanation in the context of Azure VNET Gateway.

This article describes how use the Cisco Catalyst 8000V Edge Software in Azure to build a VPN solution that supports both Source NAT and custom Traffic Selectors.

## Lab
The lab consists of two VNETs, each containing a VM and Cisco 8000V NVA. 

![image](/vpn-traffic-selector-snat.png)

The left-hand VNET is the customer's environment, the right-hand VNET represents the service provider. 
Service provider requires all traffic from the customer to be SNAT'd to 40.40.40.1. The service provider's destination systems are in the 10.10.0.0/16 range. Traffic direction is from customer to service provider only, i.e. the service provider will not need to connect to customer's systems.

The service provider requires a narrow Traffic Selector of 40.40.40.1 < - > 10.10.0.0/16.

### Deploy
Log in to Azure Cloud Shell at https://shell.azure.com/ and select Bash.

Ensure Azure CLI and extensions are up to date:
  
      az upgrade --yes
  
If necessary select your target subscription:
  
      az account set --subscription <Name or ID of subscription>
  
Clone the  GitHub repository:

      git clone https://github.com/mddazure/vpn-traffic-selector-snat

Change directory:

      cd ./vpn-traffic-selector-snat

Accept the terms for the CSR8000v Marketplace offer:

      az vm image terms accept -p cisco -f cisco-c8000v-byol --plan 17_15_01a-byol -o none

Deploy the Bicep template:

      az deployment sub create --location swedencentral --template-file templates/main.bicep

Verify that all components in the diagram above have been deployed to the resourcegroup `vpn-rg` and are healthy.

Use Serial Console from the Azure portal, under Help in the left hand menu of the Virtual machine blade, to log on to the VMs and Cisco 8000Vs.

Credentials :

Username: `AzureAdmin`

Password: `vpn@123456`

### Cisco 8000V set-up

#### Configuration

On both Cisco 8000V's:

- Connect via Serial Console and log in.

- Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Paste in the below commands:

      license boot level network-advantage addon dna-advantage
      do wr mem
      do reload

- The device will now reboot; when completed log in, en Enable mode and Configuration mode again.

Retrieve the public ip's of both Cisco 8000V's:

- `c8k-0` (left hand):
  
   ```
   az network public-ip show --resource-group vpn-lab-rg --name c8k-0-pip --query ipAddress
   ```

- c8k-10 (right hand): 

  ```
  az network public-ip show --resource-group vpn-lab-rg --name c8k-0-pip --query ipAddress
  ```

Open the file [c8k-0-snat.ios](/c8k-0-snat.ios) in a text editor.

- Replace `[c8k-10-pip]` by the public ip address of c8k-10.

- Connect to c8k-0 via Serial Console and log in.

- Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Copy the configuration into `c8k-0`.
  
- Type `end` to exit Configuration mode, type `copy run start` and accept defaults to store the running configuration.

Open the file [c8k-10-snat.ios](/c8k-10-snat.ios) in a text editor.

- Replace `[c8k-10-pip]` by the public ip address of c8k-0.

- Connect to `c8k-10` via Serial Console and log in.

- Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Copy the configuration into `c8k-10`.

- Type `end` to exit Configuration mode, type `copy run start` and accept defaults to store the running configuration.

#### Explanation

The configuration of the left-hand Cisco 8000V, `c8k-0`, consists of:

- IKEv2 and IPSec policies, profiles and transform: 

``` 
crypto ikev2 proposal IKEv2-PROPOSAL-TNTAZ 
 encryption aes-cbc-256
 integrity sha256
 group 14
!
crypto ikev2 policy IKEv2-POLICY-TNTAZ 
 proposal IKEv2-PROPOSAL-TNTAZ
!
crypto ikev2 keyring IKEv2-KEYRING-TNTAZ
 peer TNTAZ
  address 20.91.130.234
  pre-shared-key abc123
!
crypto ikev2 profile IKEv2-PROFILE-TNTAZ
 match identity remote address > 255.255.255.255 
 match identity remote address 10.10.0.4 255.255.255.255 
 !<When the remote router is in Azure, use its outside interface's private address !here. When the remote router has a public address directly on the outside interface, use its public address here> 
 authentication remote pre-share
 authentication local pre-share
 keyring local IKEv2-KEYRING-TNTAZ
!
crypto ipsec transform-set IPSEC-TRANSFORM-TNTAZ esp-aes 256 esp-sha256-hmac 
 mode tunnel
!
crypto ipsec profile IPSEC-PROFILE-TNTAZ
 set transform-set IPSEC-TRANSFORM-TNTAZ 
 set pfs group14
```
This is the same as in route-based VPN configurations.

- A crypto map, which references an access list to identify which traffic needs to encrypted:
```
crypto map cmap 1 ipsec-isakmp 
 set peer 20.91.130.234
 set transform-set IPSEC-TRANSFORM-TNTAZ 
 set ikev2-profile IKEv2-PROFILE-TNTAZ
 match address tntazlist
 ```
 This is the main difference between a policy based and a route-based VPN. In a route based VPN, the encrypted connection is represented as Virtual Tunnel Interface (VTI) that can be referenced in routes and will appear in the routing table. In the background, not visible in the configuration, this results in a 0.0.0.0/0 to 0.0.0.0/0 (any-to-any) Traffic Selector exchanged during the IKEv2 Phase 2 negotiation.

 In a policy-based VPN, the access-list referenced by the Crypto map determines which traffic is sent down the encrypted connection. There is no Virtual Tunnel Interface to reference in the routing table, traffic qualifying for encryption traffic bypasses the routing process. The Crypto map configuration results in an exchange of Traffic Selectors as specified in the access list.

- The Crypto map is attached to the outside interface of the router:

```
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 crypto map cmap
 ```

 - The access list that defines traffic to be sent through the encrypted connection:
  ```
ip access-list extended tntazlist
 10 permit ip 10.0.0.0 0.0.255.255 10.10.0.0 0.0.255.255
 20 permit ip host 40.40.40.1 10.10.0.0 0.0.255.255
 ```

 Source NAT is implemented on the left-hand router router only.
 
- Access list that defines which traffic is to be NAT'd
```
ip access-list extended snat-inside
 10 permit ip 10.0.2.0 0.0.0.255 any
 20 deny ip any any
```
 
 - NAT pool:
```
ip nat pool snat-pool 40.40.40.1 40.40.40.1 prefix-length 30
ip nat inside source list snat-inside pool snat-pool
```
- LAN interface set as inside interface:
```
interface GigabitEthernet2
 ip address dhcp
 ip nat inside
 negotiation auto
```
Traffic received on the LAN interface is compared to the access-list. If it matches, the source address is replaced as defined in the NAT pool.

The replaced source address then matches the access list attached to the crypto map, so it sent down the encrypted connection.

The right-hand router `c8k-10` is configured similarly, with following differences:
- It does not contain the Source NAT configuration.
- The access list linked to the crypto map, which controls the Traffic Selector, is the mirror image of the access list on `c8k-0`: it has source and destination reversed.

#### Testing

Log on to `client-Vm` and to `c8k-0` via Serial Console in separate portal browser windows.

On `client-Vm` start a continuous ping to `provider-VM`: `ping 10.10.2.4` and verify that the pings are successful.

On `c8k-0`, enter Enable mode and observe NAT translations in progress:

```
c8k-0#show ip nat translations 
Pro  Inside global         Inside local          Outside local         Outside global
---  40.40.40.1            10.0.2.4              ---                   ---
icmp 40.40.40.1:4682       10.0.2.4:4682         10.10.2.4:4682        10.10.2.4:4682
Total number of translations: 2
```

On `client-Vm` stop the ping. 

Connect via SSH from `client-Vm` to `provider-Vm`: `ssh AzureAdmin@10.10.2.4` and log in.

Observe the SSH_CONNECTION environment variable: 

```
AzureAdmin@provider-Vm:~$ echo $SSH_CONNECTION
40.40.40.1 35150 10.10.2.4 22
```

On `c8k-0` observe NAT translations again and compare to the SSH connection information above.

```
c8k-0#show ip nat translations verbose 
Pro  Inside global         Inside local          Outside local         Outside global
---  40.40.40.1            10.0.2.4              ---                   ---
  create: 02/12/25 16:06:36, use: 02/12/25 16:15:19, timeout: 23:53:27
  RuleID : 2
  Flags: unknown
  ALG Application Type: NA
  WLAN-Flags: unknown
  Mac-Address: 0000.0000.0000    Input-IDB: GigabitEthernet2
  entry-id: 0x0, use_count:1
  In_pkts: 0 In_bytes: 0, Out_pkts: 0 Out_bytes: 0 
  Output-IDB:  

tcp  40.40.40.1:35150      10.0.2.4:35150        10.10.2.4:22          10.10.2.4:22
  create: 02/12/25 16:15:19, use: 02/12/25 16:20:30, timeout: 23:58:38
  RuleID : 2
  Flags: unknown
  ALG Application Type: NA
  WLAN-Flags: unknown
  Mac-Address: 0000.0000.0000    Input-IDB: GigabitEthernet2
  entry-id: 0xe894bbd0, use_count:1
  In_pkts: 1503 In_bytes: 104762, Out_pkts: 1500 Out_bytes: 107698 
  Output-IDB: GigabitEthernet1 

Total number of translations: 2
```
The Inside Local address is source address of `client-Vm`. This is translated to the Outside Local address, which is the source address seen by `provider-Vm`.


