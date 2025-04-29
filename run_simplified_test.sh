#!/bin/bash

# Compile and run the simplified test
mvn clean compile

echo "Compiling simplified test..."
javac -cp "target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimplifiedTest.java

echo "Running simplified test..."
java -cp ".:target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)" SimplifiedTest