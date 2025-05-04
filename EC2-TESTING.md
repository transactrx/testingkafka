# EC2 Testing Instructions

These instructions will help you set up and run the MSK Kafka IAM authentication tests from an EC2 instance in the same VPC as your MSK cluster.

## Step 1: Launch an EC2 Instance

1. Launch an EC2 instance in the same VPC as your MSK cluster
   - Use Amazon Linux 2 or Amazon Linux 2023
   - Make sure the instance is in the same VPC as the MSK cluster
   - Ensure it has a security group that can access the MSK broker ports (14098, 14099, 14100)

2. Assign an IAM role to the instance with the following policy:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "kafka-cluster:Connect",
                   "kafka-cluster:*Topic*",
                   "kafka-cluster:WriteData",
                   "kafka-cluster:ReadData"
               ],
               "Resource": [
                   "arn:aws:kafka:*:156122716852:cluster/*/*",
                   "arn:aws:kafka:*:156122716852:topic/*/*/*"
               ]
           }
       ]
   }
   ```

## Step 2: Set Up the EC2 Instance

1. Connect to your EC2 instance:
   ```bash
   ssh -i your-key.pem ec2-user@your-instance-ip
   ```

2. Install Java and Git:
   ```bash
   sudo yum update -y
   sudo yum install -y git java-11-amazon-corretto-headless
   ```

3. Install Maven:
   ```bash
   sudo yum install -y maven
   # Or download directly if not available
   wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
   tar xzvf apache-maven-3.9.6-bin.tar.gz
   export PATH=$PATH:$(pwd)/apache-maven-3.9.6/bin
   ```

## Step 3: Clone and Run the Test Code

1. Clone the repository:
   ```bash
   git clone https://github.com/transactrx/testingkafka.git
   cd testingkafka
   ```

2. Modify the test code to use instance profile credentials:
   ```bash
   # Edit simple_producer_test.java to remove any explicit credential providers
   # The AWS SDK will automatically use the instance profile credentials
   ```

3. Compile and run the basic network test:
   ```bash
   chmod +x *.sh
   ./network_test.sh
   ```

4. Compile and run the producer test:
   ```bash
   mvn clean compile
   javac -cp "$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" simple_producer_test.java
   java -cp ".:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" simple_producer_test
   ```

## Troubleshooting

If you still encounter issues, check the following:

1. Verify your EC2 instance is in the same VPC as the MSK cluster:
   ```bash
   # Get your instance VPC ID
   aws ec2 describe-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --query 'Reservations[0].Instances[0].VpcId' --output text
   
   # Get MSK cluster VPC ID (requires MSK describe permissions)
   aws kafka list-clusters --query 'ClusterInfoList[?ClusterName==`powerlinedevkafka`].VpcId' --output text
   ```

2. Check if the MSK cluster has IAM authentication enabled:
   ```bash
   aws kafka describe-cluster --cluster-arn YOUR_CLUSTER_ARN --query 'ClusterInfo.ClientAuthentication.Sasl.Iam.Enabled' --output text
   ```

3. Verify the broker endpoints are correct:
   ```bash
   aws kafka get-bootstrap-brokers --cluster-arn YOUR_CLUSTER_ARN --query 'BootstrapBrokerStringSaslIam'
   ```

4. Test basic TCP connectivity:
   ```bash
   nc -zv boot-3om.iam.powerlinedevkafka.u02dwn.c3.kafka.us-east-1.amazonaws.com 14098
   ```

## Example EC2 User Data Script

You can use this user data script when launching an EC2 instance to automate most of the setup:

```bash
#!/bin/bash
yum update -y
yum install -y git java-11-amazon-corretto-headless maven
cd /home/ec2-user
git clone https://github.com/transactrx/testingkafka.git
cd testingkafka
chmod +x *.sh
chown -R ec2-user:ec2-user /home/ec2-user/testingkafka
```