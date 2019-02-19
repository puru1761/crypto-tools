#!/bin/bash
# Tool used to generate a self-signed certificate/key pair
# Add -v for viewing the cert in less pager
# Add p12 for generating a PKCS12 Archive

# Set up any global constants here
COMMON_NAME=$1
EXE=$(basename $0)
CERTS_DIR="${PWD}/${COMMON_NAME}.certs"

USAGE="""
usage: ${EXE} COMMON_NAME [options]

OPTIONS:
--------
-v                      Verbose output. View the text form of the x509 cert
-p12                    Generate PKCS12 Archive
"""

if [[ $# -lt 1 ]]; then
    echo "${USAGE}"
    exit
fi

mkdir -p ${CERTS_DIR}

# Generate a self signed certificate
# The Cert is generated for common name "0.0.0.0"
openssl req \
	-newkey rsa:4096 -nodes \
	-keyout "${CERTS_DIR}/${COMMON_NAME}".key -x509 \
	-days 365 \
	-subj "/C=US/ST=California/L=SVL/O=RNP/OU=Security/CN=${COMMON_NAME}" \
	-out "${CERTS_DIR}/${COMMON_NAME}.pem" \

if [[ $2 == "-v" ]]; then
	openssl x509 \
        -text \
        -noout \
        -in ${CERTS_DIR}/${COMMON_NAME}.pem | less
fi

if [[ $2 == "-p12" ]]; then
	openssl pkcs12 \
        -inkey ${CERTS_DIR}/${COMMON_NAME}.key \
        -in ${CERTS_DIR}/${COMMON_NAME}.pem \
		-export \
        -out ${CERTS_DIR}/${COMMON_NAME}.p12

    openssl pkcs12 \
        -in ${CERTS_DIR}/${COMMON_NAME}.p12 \
        -noout \
        -info
fi
