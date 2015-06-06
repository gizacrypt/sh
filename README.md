# Giza shell script

Shell script for communicating with a Giza server.

```asciiart
                _______________________
     /\        /  ____/  /____   /  _  |
   /____\     /  /_  /  /   ____/  __  |
 /________\  /______/__/_______/__/  |_|
```
Giza decrypts secrets retrieved from the Giza format, and encrypts
secrets into the Giza format.  Giza files are encrypted and double
signed PGP files.  A Giza file can in addition contain instructions on
what to do with the file, but these can be overridden using commandline
options, which are detailed below.

This script can be used to download and decrypt secrets, and to encrypt and upload them.
It requires gpg to be available and set up. 


## Usage

