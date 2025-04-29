#!/bin/bash

# Attempt to retrieve SSL certificate from the MSK brokers to check compatibility
SERVER="boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"
PORT="14098"

echo "Attempting to fetch SSL certificate from $SERVER:$PORT..."
echo | openssl s_client -connect $SERVER:$PORT -showcerts 2>/dev/null | \
  openssl x509 -text -noout

echo "Checking SSL handshake details with specific TLS versions..."

echo "Testing with TLSv1.2:"
echo | openssl s_client -connect $SERVER:$PORT -tls1_2 -showcerts 2>&1 | grep "Protocol\|Cipher\|Session\|Certificate"

echo "Testing with TLSv1.3:"
echo | openssl s_client -connect $SERVER:$PORT -tls1_3 -showcerts 2>&1 | grep "Protocol\|Cipher\|Session\|Certificate"

echo "Getting full connection debugging info for analysis:"
echo | openssl s_client -connect $SERVER:$PORT -debug -msg -state -showcerts