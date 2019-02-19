# Quick certificate

The quick-cert tool is used to generate a self-signed Cert/Key pair for a given
common name. Certs are generated in the current working directory.

## Usage and examples

The usage for the quick-cert tool is as follows:
```
$ quick-cert 

usage: quick-cert COMMON_NAME [options]

OPTIONS:
--------
-v                      Verbose output. View the text form of the x509 cert
-p12                    Generate PKCS12 Archive


```

The verbose output allows you to view the cert in a ``less`` pager.
The PKCS12 archive is a password protected archive of the cert/key pair

### Example usage

Generate a cert/key pair and pkcs12 archive:

```
$ quick-cert 1.1.1.1 -p12
Generating a 4096 bit RSA private key
.....................................................................................................................................++
........................................................++
writing new private key to '1.1.1.1.key'
-----
Enter Export Password:
Verifying - Enter Export Password:
Enter Import Password:
MAC Iteration 2048
MAC verified OK
PKCS7 Encrypted data: pbeWithSHA1And40BitRC2-CBC, Iteration 2048
Certificate bag
PKCS7 Data
Shrouded Keybag: pbeWithSHA1And3-KeyTripleDES-CBC, Iteration 2048

```

User is prompted for an import and export password


## Author(s):

* Purushottam Kulkarni (puru1761)
* Mountain View, CA
