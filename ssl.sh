#!/usr/bin/env bash
# ---------------------------------------------------------------
#   Openssl Self-Signed SSL Certificate
#   Govind Kumar <govind.kumar@infinitylabs.in>
# ---------------------------------------------------------------

# Variables  
pass='eltsen'
Null=$(2> /dev/null);
SERIAL=`cat /dev/urandom | tr -dc '1-9' | fold -w 30 | head -n 1`
HOST_IP=$(ip route get 1 | sed 's/^.*src \([^ ]*\).*$/\1/;q')
#PUBIP=$(curl https://ifconfig.me/ &> /dev/null)

cacrt=$(curl -SL https://raw.githubusercontent.com/govindinfi/ssl/main/ca.crt -o ca.crt &>/dev/null)
cakey=$(curl -SL https://raw.githubusercontent.com/govindinfi/ssl/main/ca.key -o ca.key &>/dev/null)

chmod -R 600 ca.key
chmod -R 644 ca.crt

if [ ! -f server.key ]; then
        echo -e "$r No server.key round. Generating one$c"
        openssl genrsa -out server.key 4096 &>/dev/null
fi

# Fill the necessary certificate data
CONFIG="server-cert.conf"
cat >$CONFIG <<EOT
[ req ]
default_bits                    = 4096
default_keyfile                 = ca.key
distinguished_name              = req_distinguished_name
string_mask                     = nombstr
req_extensions                  = v3_req
[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = MY
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = Perak
localityName                    = Locality Name (eg, city)
localityName_default            = Sitiawan
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = My Directory Sdn Bhd
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = Secure Web Server
commonName                      = Common Name (eg, www.domain.com)
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_max                = 40
[ v3_req ]
nsCertType                      = server
keyUsage                        = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
basicConstraints                = CA:false
subjectKeyIdentifier            = hash
EOT

openssl req -new -config $CONFIG -key server.key -subj "/CN=$HOST_IP/emailAddress=govind.kumar@infinitylabs.in/C=IN/ST=Delhi/L=Delhi/O=INFINITYLABS/OU=Automaiton" -out server.csr &>/dev/null

rm -f $CONFIG

if [ ! -f server.csr ]; then
        echo -e "$r No server.csr round. You must create that first.$c"
        exit 1
fi
# Check for root CA key
if [ ! -f ca.key -o ! -f ca.crt ]; then
        echo -e "$r You must have root CA key generated first.$c"
        exit 1
fi

# Sign it with our CA key 
# make sure environment exists

if [ ! -d ca.db.certs ]; then
    mkdir ca.db.certs
fi

if [ ! -f ca.db.$SERIAL.serial ]; then
    echo "$SERIAL" >ca.db.$SERIAL.serial
fi

if [ ! -f ca.db.index ]; then
    cp /dev/null ca.db.index
fi

# create the CA requirement to sign the cert
cat >ca.config <<EOT
[ ca ]
default_ca              = default_CA
[ default_CA ]
dir                     = .
certs                   = \$dir
new_certs_dir           = \$dir/ca.db.certs
database                = \$dir/ca.db.index
serial                  = \$dir/ca.db.$SERIAL.serial
certificate             = \$dir/ca.crt
private_key             = \$dir/ca.key
default_days            = 1825
default_crl_days        = 30
default_md              = sha256
preserve                = no
x509_extensions         = server_cert
policy                  = policy_anything
[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ server_cert ]
basicConstraints        = CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName          = @subject_alt_names

[ subject_alt_names ]
DNS.1                   = *.google.com
IP.1                    = $HOST_IP
IP.2                    = 127.0.0.1
IP.3                    = ::1
EOT

#  sign the certificate
openssl ca -config ca.config -batch -passin pass:${pass} -out server.crt -infiles server.csr &>/dev/null

openssl verify -check_ss_sig -trusted_first -verify_ip ${HOST_IP} -CAfile ca.crt server.crt | awk '{print $2}'

#  cleanup after SSLeay
rm -f ca.config
rm -rf ca.db.*
rm -rf ca.key

