#!/bin/bash

# Test direct TCP connectivity to the Kafka brokers
echo "Testing direct connectivity to Kafka brokers..."

BROKER1="boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"
BROKER2="boot-7xl.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"
BROKER3="boot-yv7.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"

PORT1="14098"
PORT2="14100"
PORT3="14099"

echo "Testing $BROKER1:$PORT1..."
nc -zv $BROKER1 $PORT1

echo "Testing $BROKER2:$PORT2..."
nc -zv $BROKER2 $PORT2

echo "Testing $BROKER3:$PORT3..."
nc -zv $BROKER3 $PORT3

echo "Resolving IP addresses..."
for broker in $BROKER1 $BROKER2 $BROKER3; do
  echo -n "$broker resolves to: "
  dig +short $broker
done

echo "All tests completed."