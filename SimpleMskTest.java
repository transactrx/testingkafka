import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListTopicsOptions;
import org.apache.kafka.clients.admin.ListTopicsResult;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

public class SimpleMskTest {
    public static void main(String[] args) {
        System.out.println("Starting minimalist MSK IAM test (with 10 second timeout)");
        
        // Check environment variables
        System.out.println("AWS_ACCESS_KEY_ID: " + 
            (System.getenv("AWS_ACCESS_KEY_ID") != null ? 
             System.getenv("AWS_ACCESS_KEY_ID").substring(0, 5) + "..." : "Not set"));
        System.out.println("AWS_SESSION_TOKEN: " + 
            (System.getenv("AWS_SESSION_TOKEN") != null ? "Present" : "Not set"));
            
        // Create admin client with minimal properties
        Properties props = new Properties();
        props.put("bootstrap.servers", 
            "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098");
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put("sasl.client.callback.handler.class", 
            "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
            
        // Set logging
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        System.setProperty("org.slf4j.simpleLogger.log.org.apache.kafka", "info");
        System.setProperty("aws.region", "us-east-1");

        // Create a single-thread executor
        ExecutorService executor = Executors.newSingleThreadExecutor();
        
        try {
            // Create admin client
            System.out.println("Creating admin client...");
            final AdminClient adminClient = AdminClient.create(props);
            
            // Execute with timeout
            System.out.println("Executing list topics with timeout...");
            Future<?> future = executor.submit(() -> {
                try {
                    ListTopicsOptions options = new ListTopicsOptions();
                    options.timeoutMs(5000); // 5 second timeout
                    ListTopicsResult topics = adminClient.listTopics(options);
                    System.out.println("Topics: " + topics.names().get(5, TimeUnit.SECONDS));
                    System.out.println("Successfully connected to MSK cluster!");
                } catch (Exception e) {
                    System.out.println("Error: " + e.getMessage());
                    if (e.getCause() != null) {
                        System.out.println("Cause: " + e.getCause().getMessage());
                    }
                } finally {
                    adminClient.close(5, TimeUnit.SECONDS);
                }
            });
            
            // Wait with timeout
            try {
                future.get(10, TimeUnit.SECONDS);
                System.out.println("Operation completed within timeout");
            } catch (TimeoutException e) {
                System.out.println("*** OPERATION TIMED OUT AFTER 10 SECONDS ***");
                System.out.println("This indicates the client is hanging during authentication or connection");
                System.out.println("Likely causes: VPC connectivity issues or IAM authentication problems");
                future.cancel(true);
            }
        } catch (Exception e) {
            System.out.println("Error: " + e.getMessage());
        } finally {
            executor.shutdownNow();
        }
        
        System.out.println("Test complete.");
    }
}
