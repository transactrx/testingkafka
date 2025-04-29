/*
 * Simple test for Kafka producer with IAM authentication
 * Only focuses on producer functionality
 */

import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;
import java.util.Properties;
import java.util.concurrent.*;
import java.util.UUID;

public class simple_producer_test {
    private static final String BOOTSTRAP_SERVERS = 
        "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098";
    private static final String TOPIC_NAME = "test-topic";
    
    public static void main(String[] args) {
        System.out.println("Starting Basic Kafka Producer Test");
        
        // Check environment variables
        String accessKey = System.getenv("AWS_ACCESS_KEY_ID");
        String sessionToken = System.getenv("AWS_SESSION_TOKEN");
        
        System.out.println("AWS_ACCESS_KEY_ID: " + 
            (accessKey != null ? accessKey.substring(0, 5) + "..." : "Not set"));
        System.out.println("AWS_SESSION_TOKEN: " + 
            (sessionToken != null ? "Present" : "Not set"));
        
        // Test TCP connectivity first
        try {
            System.out.println("Testing TCP connectivity...");
            String[] hostPort = BOOTSTRAP_SERVERS.split(":");
            String hostname = hostPort[0];
            int port = Integer.parseInt(hostPort[1]);
            
            java.net.Socket socket = new java.net.Socket();
            socket.connect(new java.net.InetSocketAddress(hostname, port), 5000);
            System.out.println("TCP connection successful!");
            socket.close();
        } catch (Exception e) {
            System.err.println("TCP connection failed: " + e.getMessage());
            e.printStackTrace();
            return;
        }
        
        // Create minimal producer properties
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BOOTSTRAP_SERVERS);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        
        // Set MSK IAM authentication with minimal settings
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        
        // Set AWS region
        System.setProperty("aws.region", "us-east-1");
        
        // Standard SSL settings
        props.put("ssl.endpoint.identification.algorithm", "https");
        props.put("ssl.enabled.protocols", "TLSv1.2,TLSv1.3");
        props.put("ssl.protocol", "TLS");
        
        // Minimal logging to avoid clutter
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        
        // Use executor with timeout to avoid hanging
        ExecutorService executor = Executors.newSingleThreadExecutor();
        
        System.out.println("Creating producer and sending a test message with 10-second timeout...");
        Future<?> future = executor.submit(() -> {
            try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
                // Create a test message
                String key = "test-key";
                String value = "test-message-" + UUID.randomUUID().toString();
                ProducerRecord<String, String> record = new ProducerRecord<>(TOPIC_NAME, key, value);
                
                // Send the message
                Future<RecordMetadata> result = producer.send(record);
                RecordMetadata metadata = result.get(5, TimeUnit.SECONDS);
                
                System.out.println("Message sent successfully to topic: " + metadata.topic() + 
                                  ", partition: " + metadata.partition() + 
                                  ", offset: " + metadata.offset());
            } catch (Exception e) {
                System.err.println("Producer error: " + e.getMessage());
                if (e.getCause() != null) {
                    System.err.println("Root cause: " + e.getCause().getMessage());
                }
            }
        });
        
        try {
            future.get(10, TimeUnit.SECONDS);
            System.out.println("Test completed within timeout period");
        } catch (TimeoutException e) {
            System.out.println("*** TEST TIMED OUT AFTER 10 SECONDS ***");
            System.out.println("The producer is hanging during connection/authentication");
            future.cancel(true);
        } catch (Exception e) {
            System.err.println("Test execution error: " + e.getMessage());
        } finally {
            executor.shutdownNow();
        }
        
        System.out.println("Test finished.");
    }
}