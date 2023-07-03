#!/bin/bash

SCRIPTDIR="`pwd`"
CERTDIR="${SCRIPTDIR}/certs"
CADIR="${SCRIPTDIR}/ca"

CACONF="${SCRIPTDIR}/openssl.cnf"
CAKEY="${CADIR}/ca.key"
CACERT="${CADIR}/ca.pem"

if [ -f "$CAKEY" ] && [ -f "${CACERT}" ]; then
    echo "Using existing CA private key"
    echo
else
    # Generate the private key for the CA:
    echo "Generating the key and certificate for the CA server"
    mkdir -p "${CADIR}" "${CERTDIR}"

    # Generate the key and certificate for the CA.
    cat <<EOF | openssl req -config ${CACONF} -nodes -new -days 900 -x509  -keyout "${CAKEY}" -out "${CACERT}"
AU
Western Australia
Perth
Moodle Pty Ltd
Moodle LMS


EOF

    echo "Generated an OpenSSL Certificate Authority"
    touch "${SCRIPTDIR}/ca/index.txt"
    echo '01' > "${SCRIPTDIR}/ca/serial.txt"
    echo
    echo "You can add this certificate to your root certificate store."

    OS=`uname -s`
    if [ "${OS}" = "Darwin" ]
    then
        echo "You can use the following command:"
        echo "sudo security add-trusted-cert -d -r trustRoot -k '/Library/Keychains/System.keychain' ${CACERT}"
        read -p "Do you want me to do that for you now? [yN]" yn
        case $yn in
            [Yy]* ) sudo security add-trusted-cert -d -r trustRoot -k '/Library/Keychains/System.keychain' "${CACERT}"; break;;
        esac
    fi

    if [ "${OS}" = "Linux" ]
    then
        echo "You can use the following command:"
        echo "sudo cp ${SCRIPTDIR}/ca/ca.pem usr/local/share/ca-certificates/moodle-docker-ca.crt && sudo update-ca-certificates"
        read -p "Do you want me to do that for you now? [yN]" yn
        case $yn in
            [Yy]* ) sudo cp "${SCRIPTDIR}/ca/ca.pem" usr/local/share/ca-certificates/moodle-docker-ca.crt && sudo update-ca-certificates; break;;
        esac

    fi
fi

if [ "$#" -lt 1 ]
then
  echo "Usage: Must supply at least one hostname."
  exit 1
fi

# The first hostname is canonical.
DOMAIN=$1

HOSTKEY="${CERTDIR}/${DOMAIN}.key"
HOSTCSR="${CERTDIR}/${DOMAIN}.csr"
HOSTCRT="${CERTDIR}/${DOMAIN}.crt"
HOSTEXT="${CERTDIR}/${DOMAIN}.ext"
HOSTP12="${CERTDIR}/${DOMAIN}.p12"

echo
echo "Generating an openssl configuration into ${HOSTEXT}"
echo

DNSCOUNT=1
for var in "$@"
do
    DNS=$(cat <<-EOF
${DNS}
DNS.${DNSCOUNT} = ${var}
EOF
)
    DNSCOUNT=$((DNSCOUNT + 1))
done

cat > "${HOSTEXT}" << EOF
[ req ]
default_bits       = 2048
default_keyfile    = ${HOSTKEY}
distinguished_name = server_distinguished_name
req_extensions     = server_req_extensions
string_mask        = utf8only

# Do not prompt and use the 'hostconfig' section for values.
prompt              = no
distinguished_name  = hostconfig

[ hostconfig ]
countryName             = AU
stateOrProvinceName     = Western Australia
localityName            = Perth
organizationName        = Moodle Pty Ltd
organizationalUnitName  = Moodle LMS
commonName              = ${DOMAIN}
emailAddress            = moodle@example.com

[ server_distinguished_name ]

countryName         = Country Name (2 letter code)
countryName_default = AU

stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Western Australia

localityName                = Locality Name (eg, city)
localityName_default        = Perth

organizationName            = Organization Name (eg, company)
organizationName_default    = Moodle Pty Ltd

organizationalUnitName         = Organizational Unit (eg, division)
organizationalUnitName_default = Moodle LMS

commonName         = Common Name (e.g. server FQDN or YOUR name)
commonName_default = ${DOMAIN}

emailAddress         = Email Address
emailAddress_default = moodle@example.com

[ server_req_extensions ]
subjectKeyIdentifier    = hash
basicConstraints        = CA:FALSE
keyUsage                = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName          = @alternate_names
[ alternate_names ]
$DNS
EOF

# Create a private key for the dev site:
echo
echo "Generating a private key for the $DOMAIN dev site"
echo
openssl genrsa -out "${HOSTKEY}" 2048

echo "Generating a CSR for $DOMAIN"
openssl req -config "${HOSTEXT}" -nodes -new -key "${HOSTKEY}" -out "${HOSTCSR}"


#Next run the command to create the certificate: using our CSR, the CA private key, the CA certificate, and the config file:
echo "Generating a certificate for $DOMAIN"
cat <<EOF | openssl req -config "${HOSTEXT}" -newkey rsa:2048 -sha256 -nodes -out "${HOSTCSR}" -outform PEM
AU
Western Australia
Perth
Moodle Pty Ltd
Moodle LMS


EOF
echo

echo "Signing the request"
openssl ca -batch -config "${CACONF}" -policy signing_policy -extensions signing_req -out "${HOSTCRT}" -infiles "${HOSTCSR}"

echo "Generating p12 certificate"
openssl pkcs12 -export -out "${HOSTP12}" -inkey "${HOSTKEY}" -in "${HOSTCRT}" -passout pass:
