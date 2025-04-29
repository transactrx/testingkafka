package com.testingkafka.producer;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListTopicsResult;
import org.apache.kafka.common.KafkaFuture;
import software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider;
import software.amazon.awssdk.regions.Region;

import java.util.Properties;
import java.util.Set;
import java.util.concurrent.ExecutionException;

public class AwsMskAuthTest {

    private static final String BOOTSTRAP_SERVERS = 
        "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098," +
        "boot-7xl.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14100," +
        "boot-yv7.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14099";

    public static void main(String[] args) {
        // Enable debug logs
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        System.setProperty("org.slf4j.simpleLogger.log.org.apache.kafka", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.software.amazon.msk", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.javax.net.ssl", "debug");
        
        System.out.println("Starting AWS MSK Authentication Test");
        
        // Verify AWS credentials
        try {
            System.out.println("Verifying AWS credentials...");
            ProfileCredentialsProvider credentialsProvider = ProfileCredentialsProvider.builder()
                .profileName("trx-processor-dev")
                .build();
                
            System.out.println("Access Key ID ends with: " + 
                credentialsProvider.resolveCredentials().accessKeyId().substring(
                    Math.max(0, credentialsProvider.resolveCredentials().accessKeyId().length() - 4)));
            
            // Set AWS region for the client
            System.setProperty("aws.region", "us-east-1");
            
            // Set credentials
            System.setProperty("aws.accessKeyId", credentialsProvider.resolveCredentials().accessKeyId());
            System.setProperty("aws.secretAccessKey", credentialsProvider.resolveCredentials().secretAccessKey());
            
            if (credentialsProvider.resolveCredentials() instanceof 
                    software.amazon.awssdk.auth.credentials.AwsSessionCredentials) {
                System.out.println("Using session credentials");
                software.amazon.awssdk.auth.credentials.AwsSessionCredentials sessionCreds = 
                    (software.amazon.awssdk.auth.credentials.AwsSessionCredentials) 
                    credentialsProvider.resolveCredentials();
                System.setProperty("aws.sessionToken", sessionCreds.sessionToken());
            } else {
                System.out.println("Using long-term credentials");
            }
        } catch (Exception e) {
            System.err.println("Error setting AWS credentials: " + e.getMessage());
            e.printStackTrace();
            return;
        }
        
        // Create admin client properties
        Properties props = new Properties();
        props.put("bootstrap.servers", BOOTSTRAP_SERVERS);
        
        // Authentication settings
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        props.put("software.amazon.msk.auth.iam.region", "us-east-1");
        
        // SSL settings - trying TLS v1.2 only with verbose debugging
        props.put("ssl.endpoint.identification.algorithm", "");
        props.put("ssl.enabled.protocols", "TLSv1.2");
        props.put("ssl.protocol", "TLSv1.2");
        props.put("ssl.provider", "SunJSSE");
        props.put("ssl.secure.random.implementation", "SHA1PRNG");
        
        // Force vanilla JDK SSL implementation
        System.setProperty("com.sun.net.ssl.checkRevocation", "false");
        System.setProperty("javax.net.debug", "ssl,handshake");
        
        // Enable more detailed SSL debug output
        System.setProperty("javax.net.debug", "all");
        props.put("ssl.debug", "all");
        
        // Connection settings
        props.put("client.dns.lookup", "use_all_dns_ips");
        props.put("request.timeout.ms", "120000");
        props.put("retry.backoff.ms", "1000");
        props.put("reconnect.backoff.ms", "1000");
        props.put("reconnect.backoff.max.ms", "10000");
        props.put("metadata.max.age.ms", "300000");
        
        System.out.println("Creating Admin client to test connectivity...");
        try (AdminClient adminClient = AdminClient.create(props)) {
            System.out.println("Listing topics to test connectivity...");
            ListTopicsResult topics = adminClient.listTopics();
            KafkaFuture<Set<String>> namesFuture = topics.names();
            
            Set<String> topicNames;
            try {
                topicNames = namesFuture.get();
                System.out.println("Successfully connected to MSK cluster!");
                System.out.println("Available topics: " + topicNames);
            } catch (InterruptedException | ExecutionException e) {
                System.err.println("Failed to list topics: " + e.getMessage());
                Throwable cause = e.getCause();
                if (cause != null) {
                    System.err.println("Cause: " + cause.getMessage());
                    cause.printStackTrace();
                } else {
                    e.printStackTrace();
                }
            }
        } catch (Exception e) {
            System.err.println("Error creating admin client: " + e.getMessage());
            e.printStackTrace();
        }
        
        System.out.println("Test completed.");
    }
}