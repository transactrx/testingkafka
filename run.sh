#!/bin/bash

# Run the Kafka producer

# Default arguments
TOPIC="test-topic"
NUM_MESSAGES=10

# Parse command line arguments
if [ "$#" -ge 1 ]; then
  TOPIC="$1"
fi

if [ "$#" -ge 2 ]; then
  NUM_MESSAGES="$2"
fi

# Run the producer
mvn clean package
java -jar target/kafka-producer-1.0-SNAPSHOT-jar-with-dependencies.jar "$TOPIC" "$NUM_MESSAGES"