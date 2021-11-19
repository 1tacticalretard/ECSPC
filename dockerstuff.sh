#!/bin/bash

cd ~ && export ecr_repo_uri="$(<ecr_repo_uri.txt)" \
&& cd /home/ubuntu/spring-petclinic/ && sudo docker build -t $ecr_repo_uri . \
&& /bin/bash docker-login.sh \
&& docker push $ecr_repo_uri:latest