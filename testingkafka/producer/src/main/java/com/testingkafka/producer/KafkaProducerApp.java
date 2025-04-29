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
        // Parse command line arguments if provided
        String topic = args.length > 0 ? args[0] : TOPIC_NAME;
        int numMessages = args.length > 1 ? Integer.parseInt(args[1]) : 10;
        
        System.out.println("Starting Kafka Producer for MSK with IAM authentication...");
        System.out.println("Bootstrap servers: " + BOOTSTRAP_SERVERS);
        System.out.println("Topic: " + topic);
        System.out.println("Number of messages to send: " + numMessages);
        
        // Create producer properties
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        
        // Set IAM authentication
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        
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