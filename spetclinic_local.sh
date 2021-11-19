#!/bin/bash

cd /home/eugene/petclinic_d+tf/ && instance_id=$(<instance_id.txt)
export db_instance_id="$(</home/eugene/dockerized_petclinic/db_instance_id.txt)"
#aws ecr get-login --no-include-email --region=us-east-2 > /home/eugene/petclinic_d+tf/docker-login.sh
sleep 3 && scp -i "/home/eugene/Downloads/yoba.pem" -o StrictHostKeyChecking=no /home/eugene/petclinic_d+tf/dockerstuff.sh /home/eugene/petclinic_d+tf/ecr_repo_uri.txt /home/eugene/petclinic_d+tf/db_instance_id.txt /home/eugene/petclinic_d+tf/instance_id.txt /home/eugene/petclinic_d+tf/docker-login.sh /home/eugene/petclinic_d+tf/mysql_part.txt /home/eugene/petclinic_d+tf/sp-run.sh /home/eugene/petclinic_d+tf/Dockerfile ubuntu@$instance_id:/home/ubuntu/
ssh -i "/home/eugene/Downloads/yoba.pem" -o StrictHostKeyChecking=no ubuntu@$instance_id "git clone https://github.com/spring-projects/spring-petclinic.git \
&& mv /home/ubuntu/Dockerfile /home/ubuntu/spring-petclinic/ \
&& cd ~ && export db_instance_id="$(<db_instance_id.txt)" \
&& sed -i 's/localhost\/petclinic/$db_instance_id:3306\/petclinic?allowPublicKeyRetrieval=true\&useSSL=false/g' /home/ubuntu/spring-petclinic/src/main/resources/application-mysql.properties \
&& mysql -h $db_instance_id -P 3306 -u petclinic -ppetclinic < mysql_part.txt \
&& cat ~/spring-petclinic/src/main/resources/application-mysql.properties \
&& cd ~ && chmod u+x docker-login.sh dockerstuff.sh && /bin/bash dockerstuff.sh"
