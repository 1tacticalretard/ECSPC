FROM maven:latest
EXPOSE 8080
COPY *.jar /
#CMD java -jar target/*.jar -Dspring-boot.run.profiles=mysql
CMD java -javaagent:dd-java-agent.jar -Ddd.profiling.enabled=true -XX:FlightRecorderOptions=stackdepth=256 -Ddd.logs.injection=true -Ddd.trace.sample.rate=1 -Ddd.service=my-app -Ddd.env=staging -jar spring-petclinic-2.4.5.jar -Ddd.version=1.0