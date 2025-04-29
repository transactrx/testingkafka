#!/bin/bash

# Final diagnostics for MSK IAM authentication

echo "=== MSK IAM Authentication Final Diagnostics ==="

# Assume the MSK role
ROLE_ARN="arn:aws:iam::148440604113:role/MSKTestRole"
ROLE_SESSION_NAME="MSKTestSession"

echo "Assuming MSK role: $ROLE_ARN"
AWS_CREDS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME" \
    --profile trx-processor-dev)

export AWS_ACCESS_KEY_ID=$(echo "$AWS_CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$AWS_CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$AWS_CREDS" | jq -r '.Credentials.SessionToken')

echo "Successfully assumed role: $(aws sts get-caller-identity | jq -r '.Arn')"

# Check for cluster resources
echo -e "\nChecking for MSK clusters in account..."
aws kafka list-clusters --region us-east-1 | jq '.ClusterInfoList[] | {Name: .ClusterName, State: .State, ARN: .ClusterArn}'

# Check IAM permissions
echo -e "\nTesting IAM permissions..."
CMD="aws kafka describe-cluster-v2 --cluster-arn arn:aws:kafka:us-east-1:148440604113:cluster/powerlinedevkafka/* 2>&1"
echo "Running: $CMD"
eval $CMD

# Test TCP connectivity to broker
BROKER="boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com"
PORT="14098"

echo -e "\nTesting TCP connectivity to $BROKER:$PORT..."
nc -zv -w 5 $BROKER $PORT 

echo -e "\nChecking SSL/TLS certificate details..."
echo | openssl s_client -connect $BROKER:$PORT 2>/dev/null | openssl x509 -noout -text | grep "Subject:"

# Create a Java test file with timeouts
cat > SimpleMskTest.java << 'EOF'
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
EOF

echo -e "\nCompiling and running minimalist test with timeout..."
mvn clean compile
javac -cp "target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimpleMskTest.java
java -cp ".:target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimpleMskTest

echo -e "\n=== Diagnostics Complete ==="
echo "Results indicate this is likely a:"
echo "1. VPC connectivity issue - you need to be connected to the proper VPC"
echo "2. IAM permission issue - the MSK cluster may need additional permissions"
echo "3. MSK cluster configuration issue - verify IAM auth is enabled correctly"
echo "4. Security group issue - ensure your IP is allowed to connect"