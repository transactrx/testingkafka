/*
 * Simple standalone test for MSK IAM authentication
 * Compile and run:
 * javac -cp "target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimplifiedTest.java
 * java -cp ".:target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimplifiedTest
 */

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListTopicsResult;
import java.util.Properties;
import java.util.concurrent.TimeUnit;
import software.amazon.awssdk.auth.credentials.ProfileCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sts.StsClient;

public class SimplifiedTest {
    private static final String BOOTSTRAP_SERVERS = 
        "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098";

    public static void main(String[] args) {
        System.out.println("Starting Simplified MSK Authentication Test");
        
        // Enable debug logs
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        System.setProperty("org.slf4j.simpleLogger.log.org.apache.kafka", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.software.amazon.msk", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.javax.net.ssl", "debug");
        
        System.setProperty("software.amazon.msk.auth.iam.debug", "true");
        
        // Verify AWS credentials and identity
        try {
            System.out.println("Verifying AWS credentials...");
            ProfileCredentialsProvider credentialsProvider = ProfileCredentialsProvider.builder()
                .profileName("trx-processor-dev")
                .build();
            
            System.out.println("Access Key ID ends with: " + 
                credentialsProvider.resolveCredentials().accessKeyId().substring(
                    Math.max(0, credentialsProvider.resolveCredentials().accessKeyId().length() - 4)));
            
            // Get STS identity
            StsClient stsClient = StsClient.builder()
                .region(Region.US_EAST_1)
                .credentialsProvider(credentialsProvider)
                .build();
            
            System.out.println("STS Identity: " + stsClient.getCallerIdentity());
            
            // Set system properties
            System.setProperty("aws.region", "us-east-1");
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
        
        // First check basic TCP connectivity
        try {
            System.out.println("Testing TCP connectivity to broker...");
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
        
        // Create admin client with minimal properties
        Properties props = new Properties();
        props.put("bootstrap.servers", BOOTSTRAP_SERVERS);
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        
        // Set JAAS config with explicit region and profile
        String jaasConfig = "software.amazon.msk.auth.iam.IAMLoginModule required " +
                         "awsProfileName=\"trx-processor-dev\" " +
                         "awsRegion=\"us-east-1\";";
        props.put("sasl.jaas.config", jaasConfig);
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        
        // Basic SSL settings 
        props.put("ssl.endpoint.identification.algorithm", "https");
        props.put("ssl.enabled.protocols", "TLSv1.2,TLSv1.3");
        props.put("ssl.protocol", "TLS");
        
        // Use JVM default truststore
        System.setProperty("javax.net.ssl.trustStore", System.getProperty("java.home") + "/lib/security/cacerts");
        System.setProperty("javax.net.ssl.trustStorePassword", "changeit");
        
        // Connection settings
        props.put("client.dns.lookup", "use_all_dns_ips");
        props.put("request.timeout.ms", "20000");
        
        System.out.println("Creating Admin client and attempting to list topics...");
        try (AdminClient adminClient = AdminClient.create(props)) {
            // Print broker addresses from metadata
            System.out.println("Admin client created. Listing topics with 30s timeout...");
            ListTopicsResult topics = adminClient.listTopics();
            
            try {
                System.out.println("Available topics: " + topics.names().get(30, TimeUnit.SECONDS));
                System.out.println("Successfully connected to MSK cluster!");
            } catch (Exception e) {
                System.err.println("Failed to list topics: " + e.getMessage());
                if (e.getCause() != null) {
                    System.err.println("Cause: " + e.getCause().getMessage());
                    e.getCause().printStackTrace();
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