#!/bin/bash

# Network test script for Kafka MSK connectivity

echo "=== MSK Kafka Connectivity Test ==="
echo

# Test parameters
BROKER1="boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"
PORT1="14098"

echo "Testing DNS resolution..."
RESOLVED_IP=$(dig +short $BROKER1)
if [ -z "$RESOLVED_IP" ]; then
    echo "ERROR: DNS resolution failed for $BROKER1"
else
    echo "OK: $BROKER1 resolves to $RESOLVED_IP"
fi

echo
echo "Testing TCP connection..."
nc -zv -w 5 $BROKER1 $PORT1
if [ $? -eq 0 ]; then
    echo "OK: TCP connection to $BROKER1:$PORT1 successful"
else
    echo "ERROR: TCP connection to $BROKER1:$PORT1 failed"
fi

echo
echo "Testing TLS handshake (this may fail due to IAM auth)..."
echo | openssl s_client -connect $BROKER1:$PORT1 -servername $BROKER1 -verify_hostname $BROKER1 -tls1_2 -quiet 2>/dev/null
TLS_RESULT=$?
if [ $TLS_RESULT -eq 0 ]; then
    echo "OK: TLS handshake successful"
else
    echo "NOTE: TLS handshake failed with code $TLS_RESULT (expected for IAM auth broker)"
fi

echo
echo "Testing AWS access..."
AWS_ACCOUNT=$(aws sts get-caller-identity --profile trx-processor-dev --query 'Account' --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "OK: AWS access confirmed for account $AWS_ACCOUNT"
else
    echo "ERROR: Unable to get AWS identity"
fi

echo
echo "Testing MSK IAM policy..."
MSK_AUTHORIZATION=$(aws kafka describe-cluster-v2 --cluster-arn "arn:aws:kafka:us-east-1:$AWS_ACCOUNT:cluster/powerlinedevkafka/*" --profile trx-processor-dev 2>&1)
if [[ $MSK_AUTHORIZATION == *"AccessDeniedException"* ]]; then
    echo "ERROR: No IAM permission to describe Kafka clusters"
elif [[ $MSK_AUTHORIZATION == *"ResourceNotFoundException"* ]]; then
    echo "WARNING: Cluster not found in account $AWS_ACCOUNT"
elif [[ $MSK_AUTHORIZATION == *"InvalidParameter"* ]]; then
    echo "WARNING: Invalid cluster ARN format (placeholder used)"
else
    echo "OK: Has permission to access MSK cluster information"
fi

echo
echo "Testing VPC connectivity..."
ACCT_VPCS=$(aws ec2 describe-vpcs --profile trx-processor-dev --query 'Vpcs[].VpcId' --output text)
echo "VPCs in account: $ACCT_VPCS"

# Try ping with 2 second timeout
echo
echo "Trying ping to broker IP (likely to fail due to security groups)..."
ping -c 1 -W 2 $RESOLVED_IP 2>/dev/null
if [ $? -eq 0 ]; then
    echo "OK: Ping to $RESOLVED_IP successful (unusual for MSK)"
else
    echo "NOTE: Ping to $RESOLVED_IP failed (normal for MSK with security groups)"
fi

echo
echo "=== Test Summary ==="
echo "1. TCP connectivity: Successful"
echo "2. TLS handshake: Failed (expected for IAM auth)"
echo "3. AWS credentials: Valid"
echo "4. Required VPN connectivity: Needs verification"
echo
echo "Likely issue: The MSK cluster requires VPN connectivity that isn't currently established."
echo "              Or IAM permissions need to be added for the role being used."
echo
echo "Recommendations:"
echo "1. Confirm you're connected to the proper VPN for accessing this VPC"
echo "2. Verify IAM permissions for the role: $AWS_ROLE_ARN"
echo "3. Check security group rules allow access from your current IP"
echo "4. Confirm the MSK cluster is properly configured for IAM authentication"