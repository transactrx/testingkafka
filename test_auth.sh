#!/bin/bash

# Compile and run the authentication test
mvn clean compile
java -classpath target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q) com.testingkafka.producer.AwsMskAuthTest