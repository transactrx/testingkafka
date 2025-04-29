# Connecting to AWS MSK Kafka Cluster in a VPC

## Connectivity Requirements

To connect to a Kafka cluster running in an AWS VPC from outside the VPC, you need:

1. **Network Connectivity to the VPC**:
   - VPN connection to the AWS VPC
   - AWS Direct Connect
   - VPC Peering connection
   - Transit Gateway configuration
   - Being in the same network (e.g., EC2 instance in the same VPC)

2. **Proper IAM Authentication**:
   - Valid AWS credentials with the correct profile
   - IAM permissions to access the MSK cluster
   - Correctly configured AWS SDK

3. **Security Group Rules**:
   - The VPC security groups must allow traffic from your client to the Kafka brokers
   - Default Kafka ports: 9092 (plaintext), 9094 (TLS), 9096, 9098 (for SASL/IAM)

## Troubleshooting Steps

1. **Check Network Connectivity**:
   - Verify you can reach the Kafka broker hostnames
   - Ensure VPN connection is active (if applicable)
   - Check if you need special network settings to access the VPC

2. **Verify AWS Credentials**:
   - Confirm the AWS profile has permissions to access the MSK cluster
   - Check if temporary credentials have expired (for SSO logins)
   - Run `aws sts get-caller-identity --profile YOUR_PROFILE` to verify identity

3. **Enable Detailed Logging**:
   - Set log level to DEBUG for more detailed Kafka client logs
   - Check for specific error messages related to authentication or connectivity

## Common Solutions

- Use a bastion host or jump server within the VPC
- Connect through a VPN to the AWS VPC
- Run your application inside the VPC (on EC2, ECS, etc.)
- Set up appropriate VPC peering if connecting from another VPC
- Increase connection timeouts when connecting through VPN or across regions