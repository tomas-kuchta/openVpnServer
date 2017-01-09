#!/bin/bash
#############################
# Easy-RSA Setup for OpenVPN
#############################
# Requires: Easy-RSA 3
#### The PKI Directory Structure
#
#  An Easy-RSA PKI contains the following directory structure:
#
#  * private/ - dir with private keys generated on this host
#  * reqs/ - dir with locally generated certificate requests (for a CA imported
#    requests are stored here)
#
#  In a clean PKI no files will exist until, just the bare directories. Commands
#  called later will create the necessary files depending on the operation.
#
#  When building a CA, a number of new files are created by a combination of
#  Easy-RSA and (indirectly) openssl. The important CA files are:
#  
#  * `ca.crt` - This is the CA certificate
#  * `index.txt` - This is the "master database" of all issued certs
#  * `serial` - Stores the next serial number (serial numbers increment)
#  * `private/ca.key` - This is the CA private key (security-critical)
#  * `certs_by_serial/` - dir with all CA-signed certs by serial number
#  * `issued/` - dir with issued certs by commonName
#
#### After Creating a PKI

rootDir=~/easy-rsa
easyRsaName=EasyRSA-3.0.1
easyRsaSrc=https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz
easyRsaTarFile=$(basename $easyRsaSrc)

outSrvDir=~/ansible/roles/openvpnServer/files
outClDir=~/ansible/roles/openvpnServer/files

serverLst="server1 server2"
clientLst="client1 client2 phone1"

caForce=0
srvForce=0
clForce=0

export EASYRSA_KEY_SIZE=2048
export EASYRSA_CA_EXPIRE=3650
export EASYRSA_CERT_EXPIRE=3650

export EASYRSA_REQ_COUNTRY="US"
export EASYRSA_REQ_PROVINCE="California"
export EASYRSA_REQ_CITY="San Francisco"
export EASYRSA_REQ_ORG="NorthBeach"
export EASYRSA_REQ_EMAIL="me@example.com"
export EASYRSA_REQ_OU="MyOrgUnit"

# Create EasyRsa directory
mkdir -p $rootDir
cd $rootDir

# Get EasyRsa
if [ ! -f $easyRsaTarFile ]; then
  wget $easyRsaSrc
fi

######################
# Server CA PKI part
######################
cd $rootDir
tar xfz $easyRsaTarFile
cd $easyRsaName

if [ ! -f ca_done ] || (( $caForce == 1 )); then
  # Creating an Easy-RSA PKI
  echo "INFO: Creating an Easy-RSA PKI"
  ./easyrsa init-pki
  echo "INFO: Building CA"
  ./easyrsa build-ca
  # Generating Diffie-Hellman (DH) params
  echo "INFO: Generating DH"
  ./easyrsa gen-dh
  # file: $rootDir/$easyRsaName/pki/dh.pem
  touch ca_done
else
  echo "WARNING: Skipping CA setup"
fi

######################
# Server certificates
######################
cd $rootDir
mkdir -p servers
cd servers
for srv in $serverLst; do
  mkdir -p $srv
  cd $srv
  tar xfz $rootDir/$easyRsaTarFile
  cd $easyRsaName
  if [ ! -f srv_done ] || (( $srvForce == 1 )); then
    # Generating server certificates
    entityName=$srv
    echo "INFO: Generating server $entityName certificate"
    ./easyrsa init-pki
    ./easyrsa gen-req $entityName nopass
    touch srv_done
  else
    echo "WARNING: Skipping server $srv certificate"
  fi
  cd ../..
done
######################
# Import and Sign Server keys by the CA
######################
cd $rootDir/$easyRsaName
for srv in $serverLst; do
  entityName=$srv
  if [ ! -f $rootDir/servers/$srv/$easyRsaName/sign_done ] || (( $srvForce == 1 )); then
    echo "INFO: Importing server $entityName certificate"
    # import server key
    ./easyrsa import-req $rootDir/servers/$srv/$easyRsaName/pki/reqs/$srv.req $entityName
    # sign server key
    echo "INFO: Signing server $entityName certificate"
    ./easyrsa sign-req server $entityName
    touch $rootDir/servers/$srv/$easyRsaName/sign_done
  else
    echo "WARNING: Skipping signing server $srv certificate"
  fi
done

######################
# Client certificate side
######################
# execute on client or in different directory
cd $rootDir
mkdir -p clients
cd clients
for cl in $clientLst; do
  mkdir -p $cl
  cd $cl
  tar xfz $rootDir/$easyRsaTarFile
  cd $easyRsaName
  if [ ! -f cl_done ] || (( $clForce == 1 )); then
    # Generate client certificates
    entityName=$cl
    echo "INFO: Generating client $entityName certificate"
    ./easyrsa init-pki
    ./easyrsa gen-req $entityName nopass
    touch cl_done
  else
    echo "WARNING: Skipping client $cl certificate"
  fi
  cd ../..
done

######################
# Import and Sign clients keys by the CA
######################
cd $rootDir/$easyRsaName
for cl in $clientLst; do
  entityName=$cl
  if [ ! -f $rootDir/clients/$cl/$easyRsaName/sign_done ] || (( $clForce == 1 )); then
    echo "INFO: Importing client $entityName certificate"
    # import client key
    ./easyrsa import-req $rootDir/clients/$cl/$easyRsaName/pki/reqs/$cl.req $entityName
    # sign Client keys
    ./easyrsa sign-req client $entityName
    touch $rootDir/clients/$cl/$easyRsaName/sign_done
  else
    echo "WARNING: Skipping signing client $cl certificate"
  fi
done

######################
# Generate static shared-secret key for client tls-auth
######################
cd $rootDir/$easyRsaName
if [ ! -f ta.key ]; then
  /usr/sbin/openvpn --genkey --secret ta.key
fi

######################
# Collect output files
######################
mkdir -p $outSrvDir $outClDir
caCrt=$(ls $rootDir/$easyRsaName/pki/ca.crt)
dh=$(ls $rootDir/$easyRsaName/pki/dh.pem)
srvCrtLst=$(for srv in $serverLst; do ls $rootDir/$easyRsaName/pki/issued/$srv.crt; done)
srvKeyLst=$(for srv in $serverLst; do ls $rootDir/servers/$srv/$easyRsaName/pki/private/$srv.key; done)
clCrtLst=$(for cl in $clientLst; do ls $rootDir/$easyRsaName/pki/issued/$cl.crt; done)
clKeyLst=$(for cl in $clientLst; do ls $rootDir/clients/$cl/$easyRsaName/pki/private/$cl.key; done)
taKey=$(ls $rootDir/$easyRsaName/ta.key)
# keyLst=$(find $rootDir -name '*.key')
# crtLst=$(find $rootDir/$easyRsaName -name '*.crt')
# dh=$(find $rootDir/$easyRsaName -name 'dh.pem')
echo "INFO: Staging server certificates to $outSrvDir"
rsync -a $caCrt $dh $srvCrtLst $srvKeyLst $taKey $outSrvDir/
echo "INFO: Staging client certificates to $outClDir"
rsync -a $caCrt $clCrtLst $clKeyLst $taKey $outClDir/

# Print instructions
echo ""
echo "INFO: EasyRSA summary"
echo "      CA certificate: $caCrt"
echo "      DH Prime: $dh"
echo "      Static shared-secret key for client tls-auth: $taKey"
echo "      Server certififcates:"
for i in $srvCrtLst; do echo "        $i"; done
echo "      Server keys:"
for i in $srvKeyLst; do echo "        $i"; done
echo "      Client Certificates"
for i in $clCrtLst; do echo "        $i"; done
echo "      Client Keys"
for i in $clKeyLst; do echo "        $i"; done

function revokeCert {
  # Revoking certs on the server and creating CRLs for systems using them
  # on server:
  cd $rootDir/$easyRsaName
  # revoke cert for EntityName
  ./easyrsa revoke EntityName
  # create CRL with all revoked certs
  ./easyrsa gen-crl
  
  # Transport CLR to all systems that reference the revoked clients/entities
}

function showClientCertDetails {
  # show requests for the cert
  ./easyrsa show-req EntityName
  # show cert details
  ./easyrsa show-cert EntityName
}

function changeClientCertPasswd {
  ./easyrsa set-rsa-pass EntityName
  ./easyrsa set-ec-pass EntityName
  # assphrase can be removed with 'nopass' flag
}

