#!/bin/bash

cd ~/spring-petclinic/
#sudo /usr/bin/java -jar /home/ubuntu/spring-petclinic-2.4.5.jar
#mvn spring-boot:run -Dspring-boot.run.profiles=mysql
sudo docker run -it -p 8080:8080 spring-petclinic