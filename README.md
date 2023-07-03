# Certificate Generator

This tool will help you to generate a local Certificate Authority, and
certificates signed by that authority

## IMPORTANT - DANGER

These are **test** Certificates and Keys only!

- Do NOT use them outside of a closed development environment.
- DO NOT commit them to the git repository.

## Generating new certificates

The `createcerts.sh` script will:

- generate a new Certificate Authority if one does not exist already
- generate a single cert with all of the names listed

For example, to generate a certificate for `webserver` with a Subject Alternate
Name of `webserver.container.docker.internal` you can run the following command:

```
./createcerts.sh webserver webserver.container.docker.internal
```

Note: Each argument is used as a subject alternative name for the certificate.

## Local Configuration

You may wish to store all of your certiifcates and their keys in another
location.

You can do so by creating a `local.conf` file with an `SSLDIR` variable set.

For example:
```
SSLDIR=/etc/ssl
```

Note: This file is sourced by the script.
