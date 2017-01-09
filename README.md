# openVpnServer Ansible Role for openSuSE 42.x
Configure OpenVpn Server on openSuSE 42.1/42.2 using Ansible

## Description:
OpenVpn server(s) will be configured as NAT routers for the connecting clients.
Clients will be assigned IPs in range defined by internalIp in roles/openvpnServer/vars/main.yml

Note: Change: dns_1 and dns_2 variables if you do not want to use Google DNS, thus shring your browsing habits with Google.

## Prerequisites:
* At least two computers with openSuse 42.x installed and configured with shh working
  One will act as openVpn server and one will act as client and for running Ansible

## Example Use:
This guide assumes working directory: ~<br>
Directory structure:<br>
&nbsp;&nbsp;openVpnServer - openVpnServer git repository and Ansible working directory<br>
&nbsp;&nbsp;easy-rsa      - directory for CA and certificate/key generation

* Install Ansible:
  * `zypper addrepo http://download.opensuse.org/repositories/systemsmanagement/openSUSE_Leap_42.1/ systemsmanagement`
  * `zypper install ansible`
* Clone openVpnServer repository
  * `git clone https://github.com/tomas-kuchta/openVpnServer.git`
* Create Hosts file - listing your OpenVpn server(s)
  * `cd openVpnServer`
  * `vi hosts`
  ```
  [openvpnServers]
  server1
  server2
  ```
* Generate CA and openVpn server + client certificates and keys
  * List your OpenVpn servers and clients in openVpnServer/scripts/README_easy-rsa_openvpn.bash<br>
    `vi scripts/README_easy-rsa_openvpn.bash`<br>
    Edit variables: `serverLst` and `clientLst`<br>
  * Execute `README_easy-rsa_openvpn.bash and follow instructions<br>
    ```
    cd ~
    ./openVpnServer/scripts/README_easy-rsa_openvpn.bash
    ```<br>
    If successful the scrip will create and stage following files to openVpnServer/roles/openvpnServer/files:<br>
    ```
    ca.crt
    ca.key
    dh2048.pem
    ta.key
    server1.crt
    server1.key
    ....
    client1.crt
    client1.key
    ....
    ```
* Test Ansible connectivity to future openVpn server(s)
  cd ~/openVpnServer
  ansible openvpnServers -i hosts -m ping
  You should see SUCCESS response from all openvpnServers listed in the hosts file
* Configure OpenVpn server(s)
  Assuming:
  * the user executing Ansible knows their password to connect to openvpnServers
  * the user executing Ansible knows password needed to become root (as by sudo command)
  ansible-playbook -i hosts -b -k -K openVpnServer.yml
  You should see configuration progress with SUCCESS responses for each step.

## Connecting to Configured OpenVpn server(s) from client commputer(s), phones, etc.
* Create client configuration directory for config. file and and needed keys and certificates
  Note: replace clientName/serverName for your true client/server machine name as you used in README_easy-rsa_openvpn.bash
  cd ~
  mkdir openVpnClient_clientName_config
  cd openVpnClient_clientName_config
  * Create client configuration file:
    vi clientName.ovpn
    client
    dev tun
    proto udp
    
    #Server IP and Port
    remote serverName 1194
    
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    mute-replay-warnings
    ca ca.crt
    cert clientName.crt
    key clientName.key
    
    #ns-cert-type server
    tls-auth ta.key 1
    cipher AES-256-CBC
    #auth SHA512
    tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA:TLS-DHE-RSA-WITH-CAMELLIA-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-128-CBC-SHA:TLS-DHE-RSA-WITH-CAMELLIA-128-CBC-SHA
    comp-lzo
  * Copy keys and certificates from ~/openVpnServer/roles/openvpnServer/files:
    ca.crt
    ta.key
    clientName.crt
    clientName.key
* On Linux using NetworkMamager:
  * Import configuration to NetworkManager --> Connection Editor --> File --> Import VPN
    Select clientName.ovpn file
  * Test Connection
* On Linux using openvpn
  cd ~/openVpnClient_clientName_config
  sudo openvpn --config clientName.ovpn




