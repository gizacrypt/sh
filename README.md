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


## SYNOPSIS
    gizacrypt [ ACTION ] [ OPTION ]... [ FILE ]

## DESCRIPTION
Giza decrypts secrets retrieved from the Giza format, and encrypts
secrets into the Giza format.  Giza files are encrypted and double
signed PGP files.  A Giza file can in addition contain instructions on
what to do with the file, but these can be overridden using commandline
options, which are detailed below.

## COMMANDS
### Actions
#### "--new"
Set the Action field to "new"
This makes the uploaded secret the first in its chain.

#### "--write"
Set the Action field to "write"
This makes the uploaded secret to be the next in its chain.

#### "--update"
Set the Action field to "update"
This re-encrypts the secret using different recipients.  The
payload and metadata must not be changed during this operation.
The uploaded file may be checked against the previous version,
to ensure that metadata was not changed.

#### "--meta"
Set the Action field to "meta"
This re-encrypts the secret using different metadata.  The
payload must not be changed during this operation.

#### "--revert"
Upload the payload of the provided old secret as the newest
version in the chain.  It may be needed to re-encrypt the
payload, as the list of recipients may have changed in the time
in between.  The payload will be re-encrypted if the provided
recipients differ from the recipients that the old secret is
encrypted for.  Provide the script with the Giza file you want
to revert to.  This option implies
**--resolve-latest**.

#### "--delete"
Mark the chain of secrets as deleted. It will no longer show up
in listings, but can be revived if the UUID of one of the
secrets is known.


## OPTIONS
### Metadata
#### "--name"
Set the name of the secret.  This name is used in listings.

#### "--comment"
Set a comment for this change.  This is shown in history
listings.

#### "--based-on"
Set the UUID of the secret this secret is based on.  This option
may also influence the Latest field, which is queried from the
server.

#### "--latest"
Set the UUID that is the latest (newest) in the chain at the
time of upload.  If the UUID is not the latest, and
**--no-resolve-latest**
is set, the upload will fail.  If
**--resolve-latest**
is set, the provided latest UUID is replaced with the actual latest
UUID.

#### "--access ACCESS_LEVEL USER_IDS"
Set the access level for the identity with the given EMAIL.  The
USER-IDS are looked up in the local GPG keychain, and should be
marked with at least marginal trust.  Multiple user ids can be
set by separating them with pluscharacters (+).  ACCESS must be
a string that contains any of the words READ+WRITE+ADMIN,
separated a plus character (+), or the single word NONE.  From
the shell, an empty string may be represented using two
identical quotes. (e.g. '')


### Secret output
#### "--callback URL"
Base URL for REST operations on the Giza server.  This option
will prevent the secret to be written to local storage.

#### "--secret-out FILE"
Path where the new secret is written.
Use - for stdout.


### Cleartext output
#### "--cleartext-out FILE"
Path where the cleartext is written.
Use - for stdout.

#### "--no-cleartext-out"
Prevent writing cleartext to the local filesystem or stdout.


### Cleartext input
#### "--cleartext-in FILE"
The updated secret payload is read from filename.  This option
will prevent interactive editing.  This option will set the
method to "upload".  This option will prevent decryption of any
existing secret.  This option can not be mixed with
**--verbatim**,
**--editor**
or
**--template**.

#### "--editor COMMAND"
Command that is used to edit the secret payload file.  The
filepath of the temporary file is appended to the command.  If
there is no previous secret to edit, the command will be run
without filepath argument.  The behaviour of this option can be
changed with
**--template**.
This option can not be mixed with
**--verbatim**.

#### "--template FILE"
Template for the new secret payload.  This option will prevent
decryption of any existing secret.  This option will override
the behaviour of
**--editor**,
which will be called with a copy of the template.  This option can not
be mixed with
**--verbatim**.

#### "--content-type CONTENT_TYPE"
Define the content-type for the input

#### "--verbatim"
Do not offer the user any interactive means of changing the contents of
the cleartext input file before it is encrypted.
It is recommended to use this option together with
**--cleartext-in**.
This option can not be mixed with
**--editor**
or
**--template**.

### Flow
#### "--[no-]resolve-latest"
Toggle resolving the latest UUID from the Giza server.
Not resolving means uploading will fail when the base 

#### "--[no-]remove-original"
Toggle removal of the input Giza file.  It is recommended that
the Giza file be removed after running this command, to ensure
that no secret information is left on the system, even if it is
encrypted.

#### "--[no-]dry-run"
Toggle dry run mode.  In dry run mode, no cryptographic
operations are attempted, no files are read or written and no
network connections are attempted.

#### "--[no-]hash-name"
Toggle hashing of the secret name.  This will cause the name
to appear as a hash in the resulting Giza file, and cause the
name to be written in cleartext either in a file beside the
newly generated Giza file, or it being sent in an HTTP header
when sending to the server.

#### "--[no-]hash-comment"
Toggle hashing of the comment.  This will cause the comment
to appear as a hash in the resulting Giza file, and cause the
comment to be written in cleartext either in a file beside the
newly generated Giza file, or it being sent in an HTTP header
when sending to the server.

## ENVIRONMENT
#### GIZA_REMOTE
Name of remote settings.

#### GIZA_KEY
Preferred PGP ID key for cryptographic operations.

#### GIZA_NOW
Current date/time, set using `date -u +%Y-%m-%dT%H:%M:%SZ`.
Normally, you wouldn't set this environment variable, and let
**gizacrypt** find out about this by itself.  However, for
writing test-cases, it may be useful to set this variable.

Gizacrypt will print out a warning to stderr when this variable
is set.

## DIAGNOSTICS
Using **--debug**,
the program will output messages starting with
**CALLED**
to stderr.
These can be used to trace which functions are entered over the
course of the execution of the program.


## BUGS
Will season your cat with salt and pepper and eat it in the most fancy
way ever.
