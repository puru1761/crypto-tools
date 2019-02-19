#!/bin/bash
# Tool used to generate a self-signed certificate/key pair
# Add -v for viewing the cert in less pager
# Add p12 for generating a PKCS12 Archive

OPTION=$1
EXE=$(basename $0)

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

COMMON_NAME=$1

# Generate a self signed certificate
# The Cert is generated for common name "0.0.0.0"
openssl req \
	-newkey rsa:4096 -nodes \
	-keyout "${COMMON_NAME}".key -x509 \
	-days 365 \
	-subj "/C=US/ST=California/L=SVL/O=RNP/OU=Security/CN=${COMMON_NAME}" \
	-out "${COMMON_NAME}".pem \

if [[ $2 == "-v" ]]; then
	openssl x509 -text -noout -in ${COMMON_NAME}.pem | less
fi

if [[ $2 == "-p12" ]]; then
	openssl pkcs12 -inkey ${COMMON_NAME}.key -in ${COMMON_NAME}.pem \
		-export -out ${COMMON_NAME}.p12
	openssl pkcs12 -in ${COMMON_NAME}.p12 -noout -info
fi
