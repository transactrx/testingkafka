# Kafka MSK IAM Producer Test

This is a simple Kafka producer for testing MSK with IAM authentication.

## Prerequisites

- Java 11+
- Maven
- AWS credentials configured for an admin role

## Building the Project

```bash
mvn clean package
```

## Running the Producer

You can run the producer using the provided script:

```bash
./testingkafka/producer/bin/run.sh [TOPIC_NAME] [NUM_MESSAGES]
```

Where:
- `TOPIC_NAME` is the Kafka topic to send messages to (default: "test-topic")
- `NUM_MESSAGES` is the number of messages to send (default: 10)

Example:
```bash
./testingkafka/producer/bin/run.sh my-test-topic 20
```

## Configuration

The producer is configured to connect to the specified MSK cluster using IAM authentication. The bootstrap servers are configured in the `KafkaProducerApp.java` file.

## AWS Credentials

The producer uses the default AWS credential provider chain, which looks for credentials in the following order:
1. Environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
2. Java system properties: `aws.accessKeyId` and `aws.secretKey`
3. The default credential profiles file: `~/.aws/credentials`
4. Amazon ECS container credentials
5. Instance profile credentials

Ensure you have valid credentials configured for a role with appropriate permissions to connect to MSK.