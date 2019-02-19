#!/bin/bash
#
# ca-tool - Tool for creating and managing a private Certificate Authority (CA)
#
# For usage, see help
# Author(s):
#
# Purushottam Kulkarni (puru1761)
# 
# Copyright (c) 2019
#

# Set up any global constants here
CMD=$1
ROOT_CA_DIR="/root/ca"
DEBUG=1 # Debug constant. set to 1 to enable

# Name of the program.
# Adapts to change if user changes it
EXE=$(basename $0)

# Usage help text
# See here for how to use the tool
USAGE="""
usage: ${EXE} CMD [CMD_ARGS]

COMMANDS:
~~~~~~~~~
root-ca					Generate Root Certificate Authority

ca-cert CA_NAME [TRUST_CHAIN]		Generate an Intermediate CA for CA_NAME
					optional: add trust root for nested CAs

keypair COMMON_NAME TRUST_CHAIN [p12]	Generate a Keypair for COMMON_NAME
					option: p12 to generate pkcs12 archive
					args: TRUST_CHAIN for nested CAs

Examples:
---------

${EXE} root-ca
${EXE} ca-cert my_intermediate_ca
${EXE} keypair 1.1.1.1 my_intermediate_ca
"""

# OpenSSL configuration used for managing Root CA.
# This is the template used for configuring the Root CA as well as any
# Intermediate CAs
#
# Taken from: https://jamielinux.com/docs/openssl-certificate-authority/appendix/root-configuration-file.html
# Great How To on generating a certificate chain. Check it out!
OPENSSL_CNF="""
# OpenSSL CA configuration file.
# Copy to '/root/ca/openssl.cnf'.

[ ca ]
# 'man ca'
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = ${DIR:-/root/ca}
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The root key and root certificate.
private_key       = \$dir/private/${KEY:-root_ca.key}
certificate       = \$dir/certs/${CERT:-root_ca.pem}

# For certificate revocation lists.
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/${CRL:-root_crl.pem}
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = ${POLICY:-policy_strict}

[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the 'ca' man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = US
stateOrProvinceName_default     = California
localityName_default            =
0.organizationName_default      = $(hostname) Ltd
organizationalUnitName_default  =
emailAddress_default            =

[ v3_ca ]
# Extensions for a typical CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for a typical intermediate CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ usr_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = \"OpenSSL Generated Client Certificate\"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = server
nsComment = \"OpenSSL Generated Server Certificate\"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
"""

show_usage() {
	echo "${USAGE}"
}

edit_root_config() {
	sudo vim ${ROOT_CA_DIR}/openssl.cnf
}

# Create the root configuration from the hard-coded config
create_root_config() {
	echo "${OPENSSL_CNF}" | sudo tee ${ROOT_CA_DIR}/openssl.cnf > /dev/null
}

# Create the CA configuration
# Patches root config with a customized patch
create_ca_config() {

	CA_NAME=$1
	CA_DIR=$2

    # This is the patch file used to generate the openssl.cnf file
    # Customizes the CA directory as well as the certificate/key names
    # It is derived from the Root CA's openssl.cnf
    # TODO: Add a methodology to adjust the policy based on user preference
	CONF_PATCH="10c10
< dir               = /root/ca
---
> dir               = ${CA_DIR}
19,20c19,20
< private_key       = \$dir/private/root_ca.key
< certificate       = \$dir/certs/root_ca.pem
---
> private_key       = \$dir/private/${CA_NAME}_ca.key
> certificate       = \$dir/certs/${CA_NAME}_ca.pem
24c24
< crl               = \$dir/crl/root_crl.pem
---
> crl               = \$dir/crl/${CA_NAME}_crl.pem
35c35
< policy            = policy_strict
---
> policy            = policy_loose"

    # Copy over the root CA's openssl.cnf
	sudo rsync -a ${ROOT_CA_DIR}/openssl.cnf ${CA_DIR}/

    # Generate the patch file for Root CA's openssl.cnf
	echo "${CONF_PATCH}" | sudo tee ${CA_DIR}/openssl.patch > /dev/null

    # Patch CA's openssl.cnf with the gerated patch
	sudo patch ${CA_DIR}/openssl.cnf ${CA_DIR}/openssl.patch > /dev/null

    # Do any debug actions here
    if [[ ${DEBUG} == 1 ]]; then
        # We are in debug mode, open the CA's openssl.cnf for user editing
	    sudo vim ${CA_DIR}/openssl.cnf
    fi

    # Clean up the patch file and the original openssl.cnf
    sudo rm  -f ${CA_DIR}/openssl.cnf.orig ${CA_DIR}/openssl.patch

}

#
# Initialize the root CA's env
# 
# Create required directories and setup their perms.
# Also initialize the serial list for the Root and an index for issued Certs
#
init_trust_root() {

    # Delete the Original root ca.
    # Only one root ca can exist at a time
	sudo rm -rf ${ROOT_CA_DIR}

    # Set up the directories to work from
	sudo mkdir -p ${ROOT_CA_DIR}
	sudo mkdir -p ${ROOT_CA_DIR}/{certs,crl,newcerts,private}
	
    # Set up permissions for the directory to hold private keys
	sudo chmod 700 ${ROOT_CA_DIR}/private

    # Initialized the issued cert index
	sudo touch ${ROOT_CA_DIR}/index.txt

    # Initialize the serial number
	echo 1000 | sudo tee ${ROOT_CA_DIR}/serial > /dev/null

	create_root_config
}

#
# Initialize the trusted CA's env
# Also generates the CA's config using the CA_NAME passed in
#
init_trust_authority() {

	CA_NAME=$1
	TRUST_CHAIN=$2

    # Generate the Name of the CA directory
	if [[ ${TRUST_CHAIN} == "" ]]; then
		CA_DIR=${ROOT_CA_DIR}/${CA_NAME}
	else
		CA_DIR=${ROOT_CA_DIR}/${TRUST_CHAIN}/${CA_NAME}
	fi
	
    # Make directories to work from
	sudo mkdir -p ${CA_DIR}
	sudo mkdir -p ${CA_DIR}/{certs,crl,csr,newcerts,private}
	
    # Set the permisions for the CA's directory
	sudo chmod 700 ${CA_DIR}/private
	sudo touch ${CA_DIR}/index.txt

    # Initialize the certificate serial numbers and crl numbers
	echo 1000 | sudo tee ${CA_DIR}/serial > /dev/null
	echo 1000 | sudo tee ${CA_DIR}/crlnumber > /dev/null

    # Create the CA's configuration using the CA's name
	create_ca_config ${CA_NAME} ${CA_DIR}
}

# Generate the Root CA certificate/key pair
# Certificate is stored at ${ROOT_CA_DIR}/certs
# Key is stored at ${ROOT_CA_DIR}/private
gen_root_keypair() {

	# Construct the Root CA Subject here
	CA_SUBJ="/C=US"
	CA_SUBJ="${CA_SUBJ}/ST=California"
	CA_SUBJ="${CA_SUBJ}/L=SVL"
	CA_SUBJ="${CA_SUBJ}/O=$(hostname) Ltd"
	CA_SUBJ="${CA_SUBJ}/OU=${USER} Certificate Authority"
	CA_SUBJ="${CA_SUBJ}/CN=$(hostname) Root CA"

	# Generate the Root CA key
	sudo openssl genrsa \
		-out ${ROOT_CA_DIR}/private/root_ca.key \
		4096

	# Set the correct permissions for the root CA key
	sudo chmod 400 ${ROOT_CA_DIR}/private/root_ca.key

	# Self-sign your Root Certificate Authority
	# Since this is private, the details can be as bogus as you like
	sudo openssl req \
		-config ${ROOT_CA_DIR}/openssl.cnf \
		-x509 \
		-new \
		-nodes \
		-key ${ROOT_CA_DIR}/private/root_ca.key \
		-days 365 \
		-extensions v3_ca \
		-out ${ROOT_CA_DIR}/certs/root_ca.pem \
		-subj "${CA_SUBJ}"

	# Open the cert data in the less pager for investigation
	sudo openssl x509 \
		-noout \
		-text \
		-in ${ROOT_CA_DIR}/certs/root_ca.pem \
		| less
}

# Generate a CA Keypair under ${ROOT_CA_DIR}
# For a nested CA this is generated under ${ROOT_CA_DIR}/${NESTED_CA_LIST}/
#
# Can generate an infinitely nested CA tree and a leaf server certificate which
# can be verified up the chain
gen_ca_keypair() {

	CA_NAME=$1
	TRUST_ROOT=$2

    # Set up the CA for this CA
    # This information is required to sign the certificate for the CA
	CA_CHAIN_DIR=${ROOT_CA_DIR}/${TRUST_ROOT}
	if [[ ${TRUST_ROOT} == "" ]]; then
		CA_DIR=${ROOT_CA_DIR}/${CA_NAME}
		CA_PARENT=root
	else
		CA_DIR=${ROOT_CA_DIR}/${TRUST_ROOT}/${CA_NAME}
		CA_PARENT=$(basename ${CA_CHAIN_DIR})
	fi

	
	# Construct the Intermediate CA Subject here
	CA_SUBJ="/C=US"
	CA_SUBJ="${CA_SUBJ}/ST=California"
	CA_SUBJ="${CA_SUBJ}/L=SVL"
	CA_SUBJ="${CA_SUBJ}/O=$(hostname) Ltd"
	CA_SUBJ="${CA_SUBJ}/OU=${CA_NAME} Certificate Authority"
	CA_SUBJ="${CA_SUBJ}/CN=${CA_NAME} Intermediate CA"

	# Generate the Intermediate CA key
	sudo openssl genrsa \
		-out ${CA_DIR}/private/${CA_NAME}_ca.key \
		4096

	# Set the correct permissions for the Intermediate CA key
	sudo chmod 400 ${CA_DIR}/private/${CA_NAME}_ca.key

	# Create Intermediate Certificate Authority CSR
	# Since this is private, the details can be as bogus as you like
	sudo openssl req \
		-config ${CA_DIR}/openssl.cnf \
		-new \
		-nodes \
		-key ${CA_DIR}/private/${CA_NAME}_ca.key \
		-out ${CA_DIR}/csr/${CA_NAME}_ca.csr \
		-subj "${CA_SUBJ}"

	# Sign the intermediate certificate with the Trust Root
	sudo openssl ca \
		-config ${CA_CHAIN_DIR}/openssl.cnf \
		-extensions v3_intermediate_ca \
		-days 3650 \
		-notext \
		-md sha256 \
		-in ${CA_DIR}/csr/${CA_NAME}_ca.csr \
		-out ${CA_DIR}/certs/${CA_NAME}_ca.pem

	sudo chmod 444 ${CA_DIR}/certs/${CA_NAME}_ca.pem

	# Open the cert data in the less pager for investigation
	sudo openssl x509 \
		-noout \
		-text \
		-in ${CA_DIR}/certs/${CA_NAME}_ca.pem \
		| less


	# Verify that the intermediate cert is correctly signed
	if [[ ${CA_PARENT} == "root" ]]; then
		VERIFY_CERT=root_ca.pem
	else
		VERIFY_CERT=fullchain.pem
	fi

	# Verify the certificate you just generated is signed.
	sudo openssl verify \
		-CAfile ${CA_CHAIN_DIR}/certs/${VERIFY_CERT} \
		${CA_DIR}/certs/${CA_NAME}_ca.pem

	# Copy the entire chain into fullchain.pem to allow easy extension
	sudo cat \
		${CA_DIR}/certs/${CA_NAME}_ca.pem \
		${CA_CHAIN_DIR}/certs/${VERIFY_CERT} \
		| sudo tee ${CA_DIR}/certs/fullchain.pem > /dev/null

	sudo chmod 444 ${CA_DIR}/certs/fullchain.pem
}

# Create your very own Server Certificate
#
# Create a Device Certificate for each domain,
# such as example.com, *.example.com, awesome.example.com
# NOTE: You MUST match CN to the domain name or ip address you want to use
gen_keypair() {

	COMMON_NAME=$1
	TRUST_ROOT=$2
	
	CERTS_DIR=${ROOT_CA_DIR}/${TRUST_ROOT}
	PWD_CERTS_DIR="${PWD}/${COMMON_NAME}_certs"
	CA_NAME=$(basename ${CERTS_DIR})

	GROUP=$(id -g -n ${USER})

    # Set up the Certificate subject
    # TODO: Create a way to provide consistent subjects
	NAME="${COMMON_NAME}.$(hostname)-${USER}"
	SUBJ="/C=US"
	SUBJ="${SUBJ}/ST=California"
	SUBJ="${SUBJ}/L=SVL"
	SUBJ="${SUBJ}/O=$(hostname) Ltd"
	SUBJ="${SUBJ}/OU=${NAME}, Inc"
	SUBJ="${SUBJ}/CN=${COMMON_NAME}"

	# make directories to work from
	mkdir -p ${PWD_CERTS_DIR}/tmp
	
    # Generate the server private key
	sudo openssl genrsa \
		-out ${CERTS_DIR}/private/${COMMON_NAME}.key \
		4096

    # Set up server private key permissions
	sudo chmod 400 ${CERTS_DIR}/private/${COMMON_NAME}.key
	sudo cp ${CERTS_DIR}/private/${COMMON_NAME}.key ${PWD_CERTS_DIR}/
	
	sudo chown ${USER}:${GROUP} ${PWD_CERTS_DIR}/${COMMON_NAME}.key
	sudo chmod 400 ${PWD_CERTS_DIR}/${COMMON_NAME}.key

	# Create a request from your Device, which your Root CA will sign
	sudo openssl req \
		-config ${CERTS_DIR}/openssl.cnf \
		-key ${CERTS_DIR}/private/${COMMON_NAME}.key \
		-new \
		-sha256 \
		-out ${CERTS_DIR}/csr/${COMMON_NAME}_csr.pem \
		-subj "${SUBJ}"

    # Create and store the Server CSR with proper perms
	sudo cp ${CERTS_DIR}/csr/${COMMON_NAME}_csr.pem ${PWD_CERTS_DIR}/tmp/
	sudo chown ${USER}:${GROUP} ${PWD_CERTS_DIR}/tmp/${COMMON_NAME}_csr.pem
	sudo chmod 444 ${PWD_CERTS_DIR}/tmp/${COMMON_NAME}_csr.pem

	# Sign the request from Device with your Trusted CA
	# Use the extension server_cert from the Trusted CA's openssl.cnf
	sudo openssl ca \
		-config ${CERTS_DIR}/openssl.cnf \
		-extensions server_cert \
		-days 375 \
		-notext \
		-md sha256 \
		-in ${CERTS_DIR}/csr/${COMMON_NAME}_csr.pem \
		-out ${CERTS_DIR}/certs/${COMMON_NAME}.cert.pem

	sudo chmod 444 ${CERTS_DIR}/certs/${COMMON_NAME}.cert.pem

    # Set up the server certificate in ${CWD} and set correct perms
	sudo cp ${CERTS_DIR}/certs/${COMMON_NAME}.cert.pem ${PWD_CERTS_DIR}/
	sudo chown ${USER}:${GROUP} ${PWD_CERTS_DIR}/${COMMON_NAME}.cert.pem

    # View the server cert in a less pager
	openssl x509 \
		-noout \
		-text \
		-in ${PWD_CERTS_DIR}/${COMMON_NAME}.cert.pem | less

    # Verify the server certificate
	sudo openssl verify \
		-CAfile ${CERTS_DIR}/certs/fullchain.pem \
		${CERTS_DIR}/certs/${COMMON_NAME}.cert.pem

	# Create a public key, for funzies
	# see https://gist.github.com/coolaj86/f6f36efce2821dfb046d
	openssl rsa \
		-in ${PWD_CERTS_DIR}/${COMMON_NAME}.key \
		-pubout \
		-out ${PWD_CERTS_DIR}/${COMMON_NAME}.pub

	# Put things in their proper place
	sudo rsync -a \
		${CERTS_DIR}/certs/fullchain.pem ${PWD_CERTS_DIR}/chain.pem
	sudo chmod 444 ${PWD_CERTS_DIR}/chain.pem
	sudo chown ${USER}:${GROUP} ${PWD_CERTS_DIR}/chain.pem

	# Generate the full server chain
	cat ${PWD_CERTS_DIR}/${COMMON_NAME}.cert.pem \
		${PWD_CERTS_DIR}/chain.pem \
		> ${PWD_CERTS_DIR}/${DEVID}/fullchain.pem
}

# Generate PKCS12 archive for a Cert/Key/CA.
# Used as an option, not enabled by default
gen_pkcs12_archive() {

	CERTS_DIR="${PWD}/certs"
	CERT_NAME="$1"

    # Generate a pkcs12 archive for the pointed cert
	openssl pkcs12 \
		-inkey ${CERTS_DIR}/${CERT_NAME}.key \
		-in ${CERTS_DIR}/${CERT_NAME}.cert.pem \
		-export -out ${CERTS_DIR}/${CERT_NAME}.cert.p12 \
		-CAfile ${CERTS_DIR}/chain.pem -chain
}

# Die if no arguments are passed
if [[ $# -lt 1 ]]; then
	show_usage
	exit 1
fi

# Parse the commandline args
case "$1" in
    
    # Generate a server Certificate/Key Pair
	keypair)
		if [[ $# -lt 2 ]]; then
			echo "error(keypair): 'COMMON_NAME' required"
			exit 1
		fi

		if [[ $# -lt 3 ]]; then
			echo "error(keypair): 'TRUST_CHAIN' required"
			exit 1
		fi

		gen_keypair $2 $3
		echo "Generated Certificate/Key Pair for '$2'"
		echo "using trust chain '$3'"

		if [[ $4 == "p12" ]]; then
			gen_pkcs12_archive $2
			echo "Generated PKCS12 Archive for '$2'"
		fi
		;;

    # Generate an Intermediate CA cert/key pair
	ca-cert)
		if [[ $# -lt 2 ]]; then
			echo "error(ca-cert) 'CA_NAME' required"
			exit 1
		fi
		
		init_trust_authority $2 $3
		gen_ca_keypair $2 $3
		echo "Generated CA Certificate/Key Pair for '$2'"
		
		if [[ $# -eq 3 ]]; then
			echo "Using Trusted Intermediate CA(s): '$3'"
		fi
		;;

    # Generate a Root CA (Note, will erase previous root CA, if it exists)
	root-ca)
		init_trust_root
		gen_root_keypair
		echo "Generated Root CA Certificate/Key Pair"
		;;
	*)
		show_usage
		exit 1
esac
