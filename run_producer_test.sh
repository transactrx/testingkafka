#!/bin/bash

# Script to assume the MSK role and test only Kafka producer functionality

# Role information
ROLE_ARN="arn:aws:iam::148440604113:role/MSKTestRole"
ROLE_SESSION_NAME="MSKTestSession"

echo "=== Testing Kafka Producer with IAM authentication ==="
echo "Assuming role: $ROLE_ARN"

# Assume the role and store credentials
AWS_CREDS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME" \
    --profile trx-processor-dev)

if [ $? -ne 0 ]; then
    echo "Error assuming role. Check your permissions and role ARN."
    exit 1
fi

# Extract the credentials from the response
export AWS_ACCESS_KEY_ID=$(echo "$AWS_CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$AWS_CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$AWS_CREDS" | jq -r '.Credentials.SessionToken')

echo "Successfully assumed role. Credentials are set as environment variables."
echo "Access Key ID: ${AWS_ACCESS_KEY_ID:0:5}..."

# Verify identity with assumed role
echo "Identity: $(aws sts get-caller-identity | jq -r '.Arn')"

# Compile and run the test
cd /Users/manuelelaraj/Documents/Github/testingkafka
mvn clean compile

echo "Compiling simple producer test..."
javac -cp "target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" simple_producer_test.java

echo "Running producer test..."
java -cp ".:target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" simple_producer_test

echo "Test completed."