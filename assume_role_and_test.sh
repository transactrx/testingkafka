#!/bin/bash

# Script to assume the MSK role and test Kafka connectivity

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

# Create a temporary AWS config file for testing
TEMP_AWS_DIR=$(mktemp -d)
AWS_CONFIG_FILE="$TEMP_AWS_DIR/config"
AWS_CREDENTIALS_FILE="$TEMP_AWS_DIR/credentials"

echo "[profile msk_test]
region = us-east-1" > "$AWS_CONFIG_FILE"

echo "[msk_test]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN" > "$AWS_CREDENTIALS_FILE"

echo "Created temporary AWS credentials in: $TEMP_AWS_DIR"

# Test the AWS credentials
echo "Testing AWS credentials..."
AWS_CONFIG_FILE="$AWS_CONFIG_FILE" AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDENTIALS_FILE" \
aws sts get-caller-identity --profile msk_test

# Modify the Java code to use these credentials
echo "Preparing test client..."
# Create a modified test file that uses the environment variables
cat > "$TEMP_AWS_DIR/EnvMSKTest.java" << 'EOF'
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListTopicsResult;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class EnvMSKTest {
    private static final String BOOTSTRAP_SERVERS = 
        "boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com:14098";

    public static void main(String[] args) {
        System.out.println("Starting MSK Authentication Test with assumed role");

        // Enable debug logs
        System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "info");
        System.setProperty("org.slf4j.simpleLogger.log.org.apache.kafka", "debug");
        System.setProperty("org.slf4j.simpleLogger.log.software.amazon.msk", "debug");
        
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
        
        // More explicit JAAS config that uses environment variables directly
        // The MSK IAM auth will automatically use AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
        String jaasConfig = "software.amazon.msk.auth.iam.IAMLoginModule required;";
        props.put("sasl.jaas.config", jaasConfig);
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        
        // SSL configurations
        props.put("ssl.endpoint.identification.algorithm", "https");
        props.put("ssl.enabled.protocols", "TLSv1.2,TLSv1.3");
        props.put("ssl.protocol", "TLS");
        
        // Connection settings
        props.put("client.dns.lookup", "use_all_dns_ips");
        props.put("request.timeout.ms", "10000");
        
        // Explicitly set region for MSK auth
        System.setProperty("aws.region", "us-east-1");
        
        System.out.println("Creating Admin client and attempting to list topics...");
        try (AdminClient adminClient = AdminClient.create(props)) {
            System.out.println("Admin client created. Listing topics with 10s timeout...");
            ListTopicsResult topics = adminClient.listTopics();
            
            try {
                System.out.println("Available topics: " + topics.names().get(10, TimeUnit.SECONDS));
                System.out.println("Successfully connected to MSK cluster!");
            } catch (Exception e) {
                System.err.println("Failed to list topics: " + e.getMessage());
                if (e.getCause() != null) {
                    System.err.println("Cause: " + e.getCause().getMessage());
                }
            }
        } catch (Exception e) {
            System.err.println("Error creating admin client: " + e.getMessage());
        }
        
        System.out.println("Test completed.");
    }
}
EOF

# Compile and run the test
echo "Compiling test with the assumed role credentials..."
cd "$TEMP_AWS_DIR"
javac -cp "$(cd /Users/manuelelaraj/Documents/Github/testingkafka && mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" EnvMSKTest.java

echo "Running test with timeout of 15 seconds..."
timeout 15 java \
    -cp ".:$(cd /Users/manuelelaraj/Documents/Github/testingkafka && mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" \
    EnvMSKTest || echo "Test timed out or failed"

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$TEMP_AWS_DIR"

echo "Test completed."