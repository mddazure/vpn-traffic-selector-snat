**VPN with Source NAT and Traffic Selector**

Some providers of IT services require their customers to conenct via VPN tunnels. 

These service providers will usually require their customers to Source NAT to - i.e. hide themselves behind - an IP address from a range they control. This ensures that all customers come in to the provider's environment from unique IP addresses. Providers may also require a custom Traffic Selector matching the Source NAT address, effectively turning the connection into a policy-based rather than a route-based VPN.

Although VPN is an outdated and cumbersome method of connecting to a central service, it is still used in some application fields such as with government agencies, regulatory bodies, tax authorities etc. Customers have no other option than to comply if they want or need to use these provider's services.

Azure customers will usually first attempt to use Azure-native VNET or VWAN VPN Gateways. These Gateways have NAT capabilities, but do ***not*** support NAT in combination with custom (policy-based) Traffic Selectors. When this combination is required, the only solution is to use a Network Virtual Appliance (NVA).

See [Comparing Cisco VPN Technologies – Policy Based vs Route Based VPNs](https://www.firewall.cx/cisco/cisco-services-technologies/cisco-comparing-vpn-technologies.html) for an explanation of these concepts from Cisco's persective.

[Connect a VPN gateway to multiple on-premises policy-based VPN devices](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-connect-multiple-policybased-rm-ps) provides an eplanation in the context of Azure VNET Gateway.

This article describes how use the Cisco Catalyst 8000V Edge Software in Azure to build a VPN solution that supports both Source NAT and custom Traffic Selectors.

# Lab
The lab consists of two VNETs, each containing a VM and Cisco 8000V NVA. 

![image](/inexto.png)

The NVA configuration consists of:

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
 match identity remote address 20.91.130.234 255.255.255.255 
 match identity remote address 10.10.0.4 255.255.255.255 
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

 Source NAT is implemented on the c8k-0 router only.
 
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
