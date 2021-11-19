terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}


provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.eu/"
}


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}
resource "aws_security_group_rule" "petclinic_rds_login" {
  security_group_id = aws_security_group.petclinic_sg.id
  type              = "ingress"
  from_port         = 3304
  to_port           = 3307
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}



resource "aws_vpc" "petclinic_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  instance_tenancy     = "default"

  tags = {
    Name = "PetClinicVPC"
  }
}
resource "aws_internet_gateway" "petclinic_igw" {
  vpc_id = aws_vpc.petclinic_vpc.id
}
resource "aws_subnet" "petclinic_subnet_primary_pub" {
  vpc_id            = aws_vpc.petclinic_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "PetClinicSN"
  }
}
resource "aws_subnet" "petclinic_subnet_secondary_pub" {
  vpc_id            = aws_vpc.petclinic_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "PetClinicSN"
  }
}
resource "aws_subnet" "petclinic_subnet_primary" {
  vpc_id            = aws_vpc.petclinic_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "PetClinicSN"
  }
}
resource "aws_subnet" "petclinic_subnet_secondary" {
  vpc_id            = aws_vpc.petclinic_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "PetClinicSN"
  }
}
resource "aws_eip" "nat_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.petclinic_igw]
}
resource "aws_eip" "nat_2" {
  vpc        = true
  depends_on = [aws_internet_gateway.petclinic_igw]
}
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.petclinic_subnet_primary.id
  depends_on    = [aws_internet_gateway.petclinic_igw]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.petclinic_subnet_secondary.id
  depends_on    = [aws_internet_gateway.petclinic_igw]
}


resource "aws_security_group" "petclinic_sg" {
  name        = "petclinic_sg"
  description = "Spring-Petclinic Security Group"
  vpc_id      = aws_vpc.petclinic_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = "0"
    to_port     = "8081"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "petclinic_sg"
  }
}

resource "aws_db_subnet_group" "petclinic_db_subnet" {
  name       = "main"
  subnet_ids = [aws_subnet.petclinic_subnet_primary.id, aws_subnet.petclinic_subnet_secondary.id, aws_subnet.petclinic_subnet_primary_pub.id, aws_subnet.petclinic_subnet_secondary_pub.id]
}
resource "aws_db_instance" "petclinic" {
  identifier             = "petclinic"
  port                   = 3306
  allocated_storage      = "5"
  engine                 = "mysql"
  engine_version         = "5.7.21"
  instance_class         = "db.t2.micro"
  name                   = "PetClinic"
  username               = "petclinic"
  password               = "petclinic"
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.petclinic_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.petclinic_db_subnet.id
  skip_final_snapshot    = true
  depends_on             = [aws_vpc.petclinic_vpc]
}

resource "aws_ecr_repository" "spring-petclinic" {
  name                 = "spring-petclinic"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecs_cluster" "petclinic_ecs_cluster" {
  name       = "PetclinicCluster"
  depends_on = [aws_vpc.petclinic_vpc]
}
resource "aws_ecs_service" "petclinic_ecs_service" {
  name                 = "ecs-service"
  cluster              = aws_ecs_cluster.petclinic_ecs_cluster.id
  task_definition      = aws_ecs_task_definition.datadog-task.family
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets          = [aws_subnet.petclinic_subnet_primary_pub.id, aws_subnet.petclinic_subnet_secondary_pub.id, aws_subnet.petclinic_subnet_primary.id, aws_subnet.petclinic_subnet_secondary.id]
    security_groups  = [aws_security_group.petclinic_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.petclinic-tg.arn
    container_name   = "spring-petclinic"
    container_port   = 8080
  }

  depends_on = [aws_alb_listener.petclinic_app, aws_iam_role_policy_attachment.ecs_task_execution_role, aws_vpc.petclinic_vpc]
}
resource "null_resource" "ecr_repo_uri" {
  provisioner "local-exec" {
    command = "touch ecr_repo_uri.txt && echo $ecr_repo_uri > ecr_repo_uri.txt && touch ecr_url.groovy && echo env.ECR_URL=$ecr_repo_uri | awk -F/ '{print $1}' > ecr_url.groovy"
    environment = {
      ecr_repo_uri = aws_ecr_repository.spring-petclinic.repository_url
    }
  }
  depends_on = [aws_ecr_repository.spring-petclinic]
}
resource "null_resource" "db_mod" {
  provisioner "local-exec" {
    command = "mysql -h $db_instance_id -P 3306 -u petclinic -ppetclinic < mysql_part.txt"
    environment = {
      db_instance_id = aws_db_instance.petclinic.address
    }
  }
  depends_on = [aws_db_instance.petclinic]
}
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_a.id
  }
}
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_b.id
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.petclinic_igw.id
  }
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.petclinic_subnet_primary_pub.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.petclinic_subnet_secondary_pub.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.petclinic_subnet_primary.id
  route_table_id = aws_route_table.private_a.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.petclinic_subnet_secondary.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ECS_TER"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}
data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
    "sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
/* resource "aws_ecs_task_definition" "petclinic_ecs_td" {
  family = "spring-petclinic"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<DEFINITION
  [
    {
      "name": "spring-petclinic",
      "image": "${aws_ecr_repository.spring-petclinic.repository_url}:latest",
      "entryPoint": [],
      "environment": [
        {
      "name": "db_instance_id",
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
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "8192"
  cpu                      = "4096"

  depends_on = [aws_vpc.petclinic_vpc] 
} */
resource "aws_elb" "petclinic_elb" {
  name            = "PetclinicELB"
  security_groups = [aws_security_group.petclinic_sg.id]
  subnets         = [aws_subnet.petclinic_subnet_primary_pub.id, aws_subnet.petclinic_subnet_secondary_pub.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 8080
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 10
  }
  tags = {
    Name = "PetclinicELB"
  }
}
output "Resource_Address" {
  value = aws_alb.alb.dns_name
}

output "Database_Address" {
  value = aws_db_instance.petclinic.address
}
resource "aws_security_group" "alb-sg" {
  name        = "petclinic_app-load-balancer-security-group"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.petclinic_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_alb" "alb" {
  name            = "spring-petclinic-loadbalanced"
  subnets         = [aws_subnet.petclinic_subnet_primary_pub.id, aws_subnet.petclinic_subnet_secondary_pub.id]
  security_groups = [aws_security_group.alb-sg.id]

}
resource "aws_alb_target_group" "petclinic-tg" {
  name        = "spring-petclinic-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.petclinic_vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 120
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/"
    interval            = 300
  }
}

resource "aws_alb_listener" "petclinic_app" {
  load_balancer_arn = aws_alb.alb.id
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.petclinic-tg.arn
  }
}
resource "aws_launch_configuration" "petclinic_lc" {

  name_prefix     = "WebServer-Highly-Available-LC-"
  image_id        = "ami-00399ec92321828f5"
  instance_type   = "t2.micro"
  user_data       = data.template_file.spetclinic_dd_init.rendered
  security_groups = [aws_security_group.petclinic_sg.id]
  depends_on      = [aws_alb.alb]
}
/* resource "aws_launch_template" "petclinic_lt" {
  name_prefix   = "petclinic_lt"
  image_id      = "ami-00399ec92321828f5"
  instance_type = "t2.micro"
  tags = {
    Name = "PetClinicLT"
  }
} */

resource "aws_autoscaling_group" "petclinic_asg" {
  vpc_zone_identifier  = [aws_subnet.petclinic_subnet_primary_pub.id, aws_subnet.petclinic_subnet_secondary_pub.id]
  load_balancers       = [aws_elb.petclinic_elb.name]
  launch_configuration = aws_launch_configuration.petclinic_lc.name
  min_size             = 1
  max_size             = 2
  //min_elb_capacity     = 1
  health_check_type = "ELB"
  depends_on        = [aws_alb.alb]
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_security_group" "ecs_sg" {
  name        = "spring-petclinic-ecs-tasks-security-group"
  description = "allow inbound access from the ALB only"
  vpc_id      = aws_vpc.petclinic_vpc.id

  ingress {
    protocol        = "-1"
    from_port       = 0
    to_port         = 0
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "datadog_monitor" "spetclinic_monitor" {
  name               = "Spring Petclinic Monitor"
  type               = "service check"
  message            = "Monitor triggered. Notify: @kush.hvm@gmail.com"
  escalation_message = "Escalation message @kush.hvm@gmail.com"

  query = "\"http.can_connect\".over(\"instance:spring-petclinic\",\"url:http://${aws_alb.alb.dns_name}\").by(\"host\",\"instance\",\"url\").last(4).count_by_status()"

  monitor_thresholds {
    warning           = 2
    warning_recovery  = 1
    critical          = 4
    critical_recovery = 3
  }

  notify_no_data    = false
  renotify_interval = 60

  notify_audit = false
  timeout_h    = 60
  include_tags = true
}
resource "aws_cloudwatch_log_group" "spetclinic_cw_log_group" {
  name              = "spring-petclinic"
  retention_in_days = 30

  tags = {
    Name = "spetclinic-cw-log-group"
  }
}
resource "aws_cloudwatch_log_stream" "spetclinic_log_stream" {
  name           = "spetclinic-log-stream"
  log_group_name = aws_cloudwatch_log_group.spetclinic_cw_log_group.name
}
data "template_file" "spetclinic_app_dd" {
  template = file("datadog-service.json")
  vars = {
    db_url     = "${aws_db_instance.petclinic.address}"
    cloudw     = "${aws_cloudwatch_log_group.spetclinic_cw_log_group.id}"
    api_key    = "${var.datadog_api_key}"
    image_link = "${aws_ecr_repository.spring-petclinic.repository_url}"
  }
}

data "template_file" "spetclinic_dd_init" {
  template = file("datadog_init.sh")
  vars = {
    alb_url = aws_alb.alb.dns_name
    api_key = var.datadog_api_key
  }
}
resource "aws_ecs_task_definition" "datadog-task" {
  family                   = "task"
  container_definitions    = data.template_file.spetclinic_app_dd.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "4096"
  cpu                      = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  depends_on               = [aws_vpc.petclinic_vpc]
}
resource "datadog_service_level_objective" "spetclinic_slo" {
  name        = "spring-petclinic"
  type        = "monitor"
  monitor_ids = [datadog_monitor.spetclinic_monitor.id]

  thresholds {
    timeframe = "7d"
    target    = 99
    warning   = 99.9
  }

}
