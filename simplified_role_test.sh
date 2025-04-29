#!/bin/bash

# A simplified test using the assumed role credentials

# Role information
ROLE_ARN="arn:aws:iam::148440604113:role/MSKTestRole"
ROLE_SESSION_NAME="MSKTestSession"

echo "=== Assuming role for MSK access ==="
echo "Assuming role: $ROLE_ARN"

# Assume the role and store credentials in a temporary file
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
echo "Testing assumed role identity:"
aws sts get-caller-identity

# Modify KafkaProducerApp.java to use these credentials directly from environment
# Create a backup first
cp /Users/manuelelaraj/Documents/Github/testingkafka/src/main/java/com/testingkafka/producer/KafkaProducerApp.java \
   /Users/manuelelaraj/Documents/Github/testingkafka/src/main/java/com/testingkafka/producer/KafkaProducerApp.java.bak

cat > /Users/manuelelaraj/Documents/Github/testingkafka/src/main/java/com/testingkafka/producer/KafkaProducerApp.java << 'EOF'
package com.testingkafka.producer;

import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;
import java.util.UUID;

public class KafkaProducerApp {
    
    private static final String BOOTSTRAP_SERVERS = 
        "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098," +
        "boot-7xl.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14100," +
        "boot-yv7.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14099";
    
    private static final String TOPIC_NAME = "test-topic";
    
    public static void main(String[] args) {
        // Enable debug for Kafka and SSL
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        System.setProperty("org.slf4j.simpleLogger.log.org.apache.kafka", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.software.amazon.msk", "debug");
        
        // Parse command line arguments if provided
        String topic = args.length > 0 ? args[0] : TOPIC_NAME;
        int numMessages = args.length > 1 ? Integer.parseInt(args[1]) : 10;
        
        System.out.println("Starting Kafka Producer for MSK with IAM authentication...");
        System.out.println("Bootstrap servers: " + BOOTSTRAP_SERVERS);
        System.out.println("Topic: " + topic);
        System.out.println("Number of messages to send: " + numMessages);
        
        // Check VPC connectivity
        try {
            for (String host : BOOTSTRAP_SERVERS.split(",")) {
                String server = host.trim();
                String hostname = server.split(":")[0];
                int port = Integer.parseInt(server.split(":")[1]);
                
                System.out.println("Testing connectivity to: " + hostname + ":" + port);
                // This will try to establish a TCP connection to the server
                java.net.Socket socket = new java.net.Socket();
                socket.connect(new java.net.InetSocketAddress(hostname, port), 5000);
                System.out.println("Successfully connected to: " + hostname + ":" + port);
                socket.close();
            }
        } catch (Exception e) {
            System.err.println("VPC connectivity issue: " + e.getMessage());
            System.err.println("You need to be connected to the proper VPC through VPN or peering to access this Kafka cluster");
            e.printStackTrace();
        }
        
        // Print environment credentials (first few chars)
        String accessKey = System.getenv("AWS_ACCESS_KEY_ID");
        String secretKey = System.getenv("AWS_SECRET_ACCESS_KEY");
        String sessionToken = System.getenv("AWS_SESSION_TOKEN");
        
        if (accessKey != null) {
            System.out.println("Using environment credentials: AWS_ACCESS_KEY_ID=" + accessKey.substring(0, 5) + "...");
        } else {
            System.out.println("No AWS_ACCESS_KEY_ID found in environment");
        }
        
        if (sessionToken != null) {
            System.out.println("Session token present in environment");
        } else {
            System.out.println("No AWS_SESSION_TOKEN found in environment");
        }
        
        // Create producer properties
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        
        // Set IAM authentication with minimal settings
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        
        // Use minimal JAAS config - the library will use environment variables automatically
        String jaasConfig = "software.amazon.msk.auth.iam.IAMLoginModule required;";
        props.put("sasl.jaas.config", jaasConfig);
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        
        // Set AWS region
        System.setProperty("aws.region", "us-east-1");
        
        // SSL configurations
        props.put("ssl.endpoint.identification.algorithm", "https");
        props.put("ssl.enabled.protocols", "TLSv1.2,TLSv1.3");
        props.put("ssl.protocol", "TLS");
        
        // Connection settings
        props.put("client.dns.lookup", "use_all_dns_ips");
        props.put("request.timeout.ms", "30000");
        props.put("retry.backoff.ms", "1000");
        props.put("reconnect.backoff.ms", "1000");
        
        // Create the producer
        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            
            // Send messages
            for (int i = 0; i < numMessages; i++) {
                String key = "key-" + i;
                String value = "message-" + i + "-" + UUID.randomUUID().toString();
                
                ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, value);
                
                // Send with callback
                Future<RecordMetadata> future = producer.send(record, (metadata, exception) -> {
                    if (exception == null) {
                        System.out.printf("Message sent successfully - Topic: %s, Partition: %d, Offset: %d%n",
                                metadata.topic(), metadata.partition(), metadata.offset());
                    } else {
                        System.err.println("Error sending message: " + exception.getMessage());
                        exception.printStackTrace();
                    }
                });
                
                try {
                    RecordMetadata metadata = future.get();  // Block to see the result
                } catch (InterruptedException | ExecutionException e) {
                    System.err.println("Failed to send message: " + e.getMessage());
                    e.printStackTrace();
                }
            }
            
            // Flush and close the producer
            producer.flush();
            System.out.println("All messages sent successfully!");
            
        } catch (Exception e) {
            System.err.println("Error creating Kafka producer: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
EOF

echo "Running Kafka producer with simplified configuration..."
cd /Users/manuelelaraj/Documents/Github/testingkafka
mvn clean compile
java -cp "target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" com.testingkafka.producer.KafkaProducerApp "test-topic" 1

# Restore the original file
mv /Users/manuelelaraj/Documents/Github/testingkafka/src/main/java/com/testingkafka/producer/KafkaProducerApp.java.bak \
   /Users/manuelelaraj/Documents/Github/testingkafka/src/main/java/com/testingkafka/producer/KafkaProducerApp.java

echo "Test completed."