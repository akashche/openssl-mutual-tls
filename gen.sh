#!/bin/bash

set -e
set -x

CA_START_DATE=20150101000000Z
CA_END_DATE=20200101000000Z

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

rm -rf "$SCRIPT_DIR"/out
mkdir "$SCRIPT_DIR"/out
rm -rf "$SCRIPT_DIR"/work
mkdir "$SCRIPT_DIR"/work
pushd "$SCRIPT_DIR"/work > /dev/null

# CA directories
mkdir ./CA
mkdir ./CA/certs
mkdir ./CA/db
mkdir ./CA/private
touch ./CA/db/index
echo 01 > ./CA/db/serial

# CA request
openssl req -new -config "$SCRIPT_DIR"/openssl.conf -out rootca.csr -keyout ./CA/private/rootca.key -passout pass:1234

# sign CA
openssl ca -selfsign -config "$SCRIPT_DIR"/openssl.conf -in rootca.csr -out ./CA/rootca.pem -extensions ca_ext -passin pass:1234 -batch

# bare CA
openssl x509 -in ./CA/rootca.pem -outform PEM -out ./CA/rootca-bare.pem

# DER CA
openssl x509 -in ./CA/rootca.pem -outform DER -out ./CA/rootca.der

# truststore CA
keytool -importcert -file ./CA/rootca.der -keystore truststore.jks -alias "Test Root CA" -storepass 123456 -storetype jks -noprompt

# server
openssl req -new -newkey rsa:2048 -subj "/C=US/O=Test Inc./OU=Engineering/CN=Test Server" -keyout server.key -out server.csr -passout pass:1234
openssl ca -config "$SCRIPT_DIR"/openssl.conf -in server.csr -out server.pem -extensions server_ext -passin pass:1234 -batch
openssl x509 -in server.pem -outform PEM -out server-bare.pem

# client 1
openssl req -new -newkey rsa:2048 -subj "/C=US/O=Test Inc./OU=Engineering/CN=Test Client 1" -keyout client1.key -out client1.csr -passout pass:1234
openssl ca -config "$SCRIPT_DIR"/openssl.conf -in client1.csr -out client1.pem -extensions client_ext -passin pass:1234 -batch
openssl pkcs12 -export -in client1.pem -inkey client1.key -out client1.p12 -name "Test Client 1" -caname "Test Root CA" -chain -CAfile ./CA/rootca.pem -passin pass:1234 -passout pass:1234

# client 2
openssl req -new -newkey rsa:2048 -subj "/C=US/O=Test Inc./OU=Engineering/CN=Test Client 2" -keyout client2.key -out client2.csr -passout pass:1234
openssl ca -config "$SCRIPT_DIR"/openssl.conf -in client2.csr -out client2.pem -extensions client_ext -passin pass:1234 -batch
openssl pkcs12 -export -in client2.pem -inkey client2.key -out client2.p12 -name "Test Client 2" -caname "Test Root CA" -chain -CAfile ./CA/rootca.pem -passin pass:1234 -passout pass:1234

# create keystore
keytool -importkeystore -srckeystore client1.p12 -srcstoretype pkcs12 -srcstorepass 1234 -destkeystore keystore.jks -deststoretype jks -deststorepass 123456
keytool -importkeystore -srckeystore client2.p12 -srcstoretype pkcs12 -srcstorepass 1234 -destkeystore keystore.jks -deststoretype jks -deststorepass 123456
keytool -importcert -file ./CA/rootca.der -keystore keystore.jks -alias "Test Root CA" -storetype jks -storepass 123456 -noprompt

# output
cp ./CA/rootca-bare.pem "$SCRIPT_DIR"/out/ca.pem
cp server-bare.pem "$SCRIPT_DIR"/out/server.pem
cp server.key "$SCRIPT_DIR"/out/server.key
cp truststore.jks "$SCRIPT_DIR"/out/
cp keystore.jks "$SCRIPT_DIR"/out/
echo 1234 > "$SCRIPT_DIR"/out/password.txt