# Certificate Authority (CA) Tool

This is a tool used to manage a certificate authority and create:
* Root CA Certificate
* Intermediate CA Certificates
* Individual Server certificates

The certificates are signed as:
```
Root CA ---> Intermediate CA ---> Server Cert
```

It also allows a chain of nested CAs as follows:
```
Root CA ---> CA 1 ---> CA 2 ---> ... CA n ---> Server Cert
```

When generating a server certificate, the trust chain leading the root CA must
be specified as well.

## Help text

The ca-tool has the following help text:
```
$ ./ca-tool.sh help

usage: ca-tool.sh CMD [CMD_ARGS]

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

ca-tool.sh root-ca
ca-tool.sh ca-cert my_intermediate_ca
ca-tool.sh keypair 1.1.1.1 my_intermediate_ca

```

We cam create a Root CA, Intermediate CA and server certificate which are
signed in a chain.

## Usage examples

This section will show how the ca-tool is used. The entire workflow, from
generating a Root CA to generating a Server Certificate is documented here.

### Generating a Root CA certificate/key pair

Before generating the Server certificate, it is necessary to set up  a Root
Certificate Authority. This can be done as follows:

```
$ ./ca-tool.sh root-ca
[sudo] password for puruk: 
Generating RSA private key, 4096 bit long modulus
.................++
.......++
e is 65537 (0x10001)
Generated Root CA Certificate/Key Pair

```

This generates a Root CA certificate/key pair in the ```/root/ca``` directory.
The ```/root/ca``` directory looks like:
```
$ sudo tree /root/ca
/root/ca
├── certs
│   └── root_ca.pem
├── crl
├── index.txt
├── newcerts
├── openssl.cnf
├── private
│   └── root_ca.key
└── serial

4 directories, 5 files
```

### Generate a Intermediate CA Certificate Key Pair

It is good practice to have your server certificate signed by an Intermediate
CA. The ca-tool allows you to create an intermediate CA signed by the root CA.
This can be done as follows:

```
$ ./ca-tool.sh ca-cert IntermediateCA
Generating RSA private key, 4096 bit long modulus
...............................................................................................................................................................................................++
.........................................................++
e is 65537 (0x10001)
Using configuration from /root/ca//openssl.cnf
Check that the request matches the signature
Signature ok
Certificate Details:
        Serial Number: 4096 (0x1000)
        Validity
            Not Before: Feb 18 22:31:35 2019 GMT
            Not After : Feb 15 22:31:35 2029 GMT
        Subject:
            countryName               = US
            stateOrProvinceName       = California
            organizationName          = ubuntu-dev Ltd
            organizationalUnitName    = IntermediateCA Certificate Authority
            commonName                = IntermediateCA Intermediate CA
        X509v3 extensions:
            X509v3 Subject Key Identifier: 
                93:7C:0B:9A:B1:5A:73:41:CA:CE:E9:6B:32:12:14:B6:C2:D7:C6:BF
            X509v3 Authority Key Identifier: 
                keyid:FF:3F:14:99:48:B5:B7:B9:C2:2B:AF:94:39:F2:65:13:91:32:2A:E6

            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
Certificate is to be certified until Feb 15 22:31:35 2029 GMT (3650 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
/root/ca/IntermediateCA/certs/IntermediateCA_ca.pem: OK
Generated CA Certificate/Key Pair for 'IntermediateCA'
```
The certificates for this Intermediate CA are stored under
```/root/ca/IntermediateCA```. This has the following directory Structure:

```
$ sudo tree /root/ca/IntermediateCA
/root/ca/IntermediateCA
├── certs
│   ├── fullchain.pem
│   └── IntermediateCA_ca.pem
├── crl
├── crlnumber
├── csr
│   └── IntermediateCA_ca.csr
├── index.txt
├── newcerts
├── openssl.cnf
├── openssl.cnf.orig
├── openssl.patch
├── private
│   └── IntermediateCA_ca.key
└── serial

5 directories, 10 files
```

We can also create an Intermediate CA from the Intermediate CA we just created.
This can be levaraged for having Nested CAs
```
$ ./ca-tool.sh ca-cert IntermediateCA2 IntermediateCA
Generating RSA private key, 4096 bit long modulus
..........++
.................................++
e is 65537 (0x10001)
Using configuration from /root/ca/IntermediateCA/openssl.cnf
Check that the request matches the signature
Signature ok
Certificate Details:
        Serial Number: 4096 (0x1000)
        Validity
            Not Before: Feb 18 22:42:56 2019 GMT
            Not After : Feb 15 22:42:56 2029 GMT
        Subject:
            countryName               = US
            stateOrProvinceName       = California
            localityName              = SVL
            organizationName          = ubuntu-dev Ltd
            organizationalUnitName    = IntermediateCA2 Certificate Authority
            commonName                = IntermediateCA2 Intermediate CA
        X509v3 extensions:
            X509v3 Subject Key Identifier: 
                D0:7D:96:17:13:6A:5B:8F:B8:56:29:B4:41:FD:15:29:F3:AB:4E:01
            X509v3 Authority Key Identifier: 
                keyid:93:7C:0B:9A:B1:5A:73:41:CA:CE:E9:6B:32:12:14:B6:C2:D7:C6:BF

            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
Certificate is to be certified until Feb 15 22:42:56 2029 GMT (3650 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
/root/ca/IntermediateCA/IntermediateCA2/certs/IntermediateCA2_ca.pem: OK
Generated CA Certificate/Key Pair for 'IntermediateCA2'
Using Trusted Intermediate CA(s): 'IntermediateCA'
```

Here we created an ```IntermediateCA2``` Certificate/Key Pair issued by the
IntermediateCA certificate authority. We will now use this nested CA to issue
our server certificate. The final directory structure of the CAs is:
```
$ sudo tree /root/ca -d
/root/ca
├── certs
├── crl
├── IntermediateCA
│   ├── certs
│   ├── crl
│   ├── csr
│   ├── IntermediateCA2
│   │   ├── certs
│   │   ├── crl
│   │   ├── csr
│   │   ├── newcerts
│   │   └── private
│   ├── newcerts
│   └── private
├── newcerts
└── private

16 directories
```

### Generating the Signed Server Certificate and CA Cert bundle

Now we generate the server certificate for our Application using the
IntermediateCA/IntermediateCA2 trust chain. This means that we need to use the
chain of certificates leading up to the root CA.

This is done as follows:
```
$ ./ca-tool.sh keypair "1.1.1.1" IntermediateCA/IntermediateCA2
Generating RSA private key, 4096 bit long modulus
....................................................................................++
...................++
e is 65537 (0x10001)
Using configuration from /root/ca/IntermediateCA/IntermediateCA2/openssl.cnf
Check that the request matches the signature
Signature ok
Certificate Details:
        Serial Number: 4096 (0x1000)
        Validity
            Not Before: Feb 18 22:51:29 2019 GMT
            Not After : Feb 28 22:51:29 2020 GMT
        Subject:
            countryName               = US
            stateOrProvinceName       = California
            localityName              = SVL
            organizationName          = ubuntu-dev Ltd
            organizationalUnitName    = 1.1.1.1.ubuntu-dev-puruk, Inc
            commonName                = 1.1.1.1
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            Netscape Cert Type: 
                SSL Server
            Netscape Comment: 
                OpenSSL Generated Server Certificate
            X509v3 Subject Key Identifier: 
                51:A8:0B:4D:B8:9D:13:9D:F0:61:EA:00:76:88:35:B7:6B:84:EC:7A
            X509v3 Authority Key Identifier: 
                keyid:D0:7D:96:17:13:6A:5B:8F:B8:56:29:B4:41:FD:15:29:F3:AB:4E:01
                DirName:/C=US/ST=California/O=ubuntu-dev Ltd/OU=IntermediateCA Certificate Authority/CN=IntermediateCA Intermediate CA
                serial:10:00

            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
Certificate is to be certified until Feb 28 22:51:29 2020 GMT (375 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
/root/ca/IntermediateCA/IntermediateCA2/certs/1.1.1.1.cert.pem: OK
writing RSA key
Generated Certificate/Key Pair for '1.1.1.1'
using trust chain 'IntermediateCA/IntermediateCA2'
```

This creates a signed server certificate in you Current Working directory as
well as a CA cert bundle which can be used to verify the certificate. The name
and structure of this directory is `${COMMON_NAME}_certs` and contains:

```
$ tree 1.1.1.1_certs/
1.1.1.1_certs/
├── 1.1.1.1.cert.pem
├── 1.1.1.1.key
├── 1.1.1.1.pub
├── chain.pem
├── fullchain.pem
└── tmp
    └── 1.1.1.1_csr.pem

    1 directory, 6 files
```

Here chain.pem contains the CA cert-bundle, 1.1.1.1.cert.pem contains the 
server certificate, and 1.1.1.1.key contains the server private key

## Future Work

We must add support for:
* Listing all available CAs and Nested CAs for the root/Intermediate CA
* List all certificates issued by a particular CA
* Revoking a certificate

## Author

* Purushottam Kulkarni (puru1761@gmail.com)
* Mountain View, CA
