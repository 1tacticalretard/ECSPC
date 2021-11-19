resource "aws_ecr_repository" "spring-petclinic" {
  name                 = "spring-petclinic"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
 resource "aws_ecs_cluster" "petclinic_ecs_cluster" {
  name = "petclinic_cluster"
  depends_on = [null_resource.local_part]
}
resource "aws_ecs_task_definition" "petclinic_ecs_td" {
  family = "taskdef"

  container_definitions = <<DEFINITION
  [
    {
      "name": "container",
      "image": "${aws_ecr_repository.spring-petclinic.repository_url}/spring-petclinic:latest",
      "entryPoint": [],
      "environment": [
        {
      "name": "MY_MYSQL_URL",
      "value": "${aws_db_instance.petclinic.address}"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "cpu": 2048,
      "memory": 2048,
      "networkMode": "awsvpc"
    }
  ]
  DEFINITION
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  memory                   = "8192"
  cpu                      = "4096"

  depends_on               = [aws_vpc.petclinic_vpc,null_resource.local_part]
}
resource "aws_ecs_service" "petclinic_ecs_service" {
  name                 = "ecs-service"
  cluster              = aws_ecs_cluster.petclinic_ecs_cluster.id
  task_definition      = "${aws_ecs_task_definition.petclinic_ecs_td.family}"
  launch_type          = "EC2"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets          = [aws_subnet.petclinic_subnet.id]
    assign_public_ip = true
    security_groups = [aws_security_group.petclinic_sg.id]
  }
  depends_on = [aws_ecs_cluster.petclinic_ecs_cluster]
}
