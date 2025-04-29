# MSK Kafka Connectivity Troubleshooting

Based on our troubleshooting, here's what we've found and the recommendations for connecting to the MSK cluster with IAM authentication.

## Current Status

- ✅ TCP connectivity to broker endpoints works (port connectivity is open)
- ✅ DNS resolution is working for broker hostnames
- ✅ AWS credentials are valid and authenticated
- ✅ Basic MSK API permissions appear to be valid
- ❌ TLS/SSL handshake is failing during the authentication phase
- ❌ Kafka client cannot establish a full authenticated connection

## Likely Causes

1. **VPN Connectivity Issues**: While you have basic network connectivity, you may not be connected to the proper VPN that provides full access to the VPC where MSK is deployed.

2. **IAM Permission Issues**: Your AWS credentials have basic permissions but may be missing specific MSK IAM authentication permissions.

3. **Kafka Security Group Rules**: The MSK cluster security group may not allow access from your current IP address/network range.

4. **TLS Configuration Mismatch**: There may be specific TLS/SSL requirements that aren't matched by the current client configuration.

## Recommended Actions

1. **Verify VPN Connectivity**
   - Confirm you're connected to the correct VPN for this environment
   - Ensure the VPN configuration routes traffic for the `100.101.198.x` IP range through the VPN
   - Check with network admin if additional VPN configuration is needed

2. **Check IAM Permissions**
   - Ensure your IAM role (AWSReservedSSO_AdministratorAccess_72b21861797fce60) has the following permissions:
     - `kafka:DescribeCluster`
     - `kafka:GetBootstrapBrokers`
     - `kafka-cluster:Connect`
     - `kafka-cluster:DescribeTopic`
     - `kafka-cluster:DescribeGroup`

3. **Security Group Verification**
   - Have a network admin verify if the MSK cluster's security group allows connections from your current network

4. **Test With Different Client Configuration**
   - Try using the AWS MSK CLI instead of Java client:
     ```
     aws kafka get-bootstrap-brokers --cluster-arn <cluster-arn> --profile trx-processor-dev
     ```
   - Try using a different AWS client tool from an EC2 instance in the same VPC

5. **MSK Cluster Configuration**
   - Verify that IAM authentication is properly enabled on the MSK cluster
   - Check if the cluster requires additional security settings

## Java Client Changes to Try

If you continue using the Java client, try these configuration changes:

```java
// Try with simplified IAM config
props.put("security.protocol", "SASL_SSL");
props.put("sasl.mechanism", "AWS_MSK_IAM");
props.put("sasl.jaas.config", 
    "software.amazon.msk.auth.iam.IAMLoginModule required;");
props.put("sasl.client.callback.handler.class", 
    "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

// Try with environment variables instead of system properties
// AWS_ACCESS_KEY_ID=your_access_key
// AWS_SECRET_ACCESS_KEY=your_secret_key
// AWS_SESSION_TOKEN=your_session_token

// Try with direct client endpoint
// Get this from AWS console or CLI
props.put("bootstrap.servers", "b-1.yourmskcluster.123456.c2.kafka.us-east-1.amazonaws.com:9098");
```

## AWS CLI for Testing

```bash
# Get the bootstrap brokers
aws kafka get-bootstrap-brokers --cluster-arn <MSK_CLUSTER_ARN> --profile trx-processor-dev

# Describe the cluster
aws kafka describe-cluster --cluster-arn <MSK_CLUSTER_ARN> --profile trx-processor-dev
```

## Other Troubleshooting Tools

- The `network_test.sh` script in this repository can help diagnose basic connectivity.
- AWS VPC Network Analyzer can help identify potential network connectivity issues.
- Check AWS CloudTrail for any access denied events related to MSK.