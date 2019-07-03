# Provider - which cloud i am using
provider "aws" {
  region = "${var.aws_region}"
}

# Define our VPC
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags = {
    Name = "Test-VPC"
  }
}

# Define the public subnet
resource "aws_subnet" "public-subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.public_subnet_cidr}"
  availability_zone = "${var.public_subnet_az}"
  map_public_ip_on_launch= true

  tags = {
    Name = "Test-VPC Public Subnet"
  }
}

# Define the private subnet
resource "aws_subnet" "private-subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.private_subnet_cidr}"
  availability_zone = "${var.private_subnet_az}"

  tags = {
    Name = "Test-VPC Private Subnet"
  }
}

# Define the internet gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "Test-VPC IGW"
  }
}

# Define the route table
resource "aws_route_table" "public-RT" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IGW.id}"
  }

  tags = {
    Name = "Test-VPC Public Subnet RT"
  }
}

# Assign the route table to the public Subnet
resource "aws_route_table_association" "public-RT" {
  subnet_id = "${aws_subnet.public-subnet.id}"
  route_table_id = "${aws_route_table.public-RT.id}"
}

# Define the security group for public subnet
resource "aws_security_group" "sgweb" {
  name = "vpc_test_web"
  description = "Allow incoming HTTP connections & SSH access"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id="${aws_vpc.main.id}"

  tags = {
    Name = "Web Server SG"
  }
}

# Define the security group for private subnet
resource "aws_security_group" "sgdb"{
  name = "sg_test_web"
  description = "Allow traffic from public subnet"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["${var.public_subnet_cidr}"]
  }

  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "DB SG"
  }
}

# Define SSH key pair for our instances
resource "aws_key_pair" "default" {
  key_name = "vpctestkeypair"
  public_key = "${file("${var.key_path}")}"
}

## Creating Launch Configuration
resource "aws_launch_configuration" "test" {
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.sgweb.id}"]
  key_name = "${aws_key_pair.default.id}"
  user_data = "${file("install.sh")}"
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "test" {
  launch_configuration = "${aws_launch_configuration.test.id}"
  vpc_zone_identifier       = ["${aws_subnet.public-subnet.id}"]
  min_size = 2
  max_size = 10
  load_balancers = ["${aws_elb.app.name}"]
  health_check_type = "ELB"

}

resource "aws_autoscaling_policy" "staging_memory" {
  name = "memory-reservation"

  autoscaling_group_name = "${aws_autoscaling_group.test.id}"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      metric_dimension {
        name  = "ClusterName"
        value = "staging"
      }

      metric_name = "MemoryReservation"
      namespace   = "AWS/ECS"
      statistic   = "Maximum"
    }

    target_value = "75"
  }
}

resource "aws_elb" "app" {
  /* Requiered for EC2 ELB only
    availability_zones = "${var.zones}"
  */
  name            = "test-elb"
  subnets         = ["${aws_subnet.public-subnet.id}"]
  security_groups = ["${aws_security_group.sgweb.id}"]
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  cross_zone_load_balancing   = true
  idle_timeout                = 960  # set it higher than the conn. timeout of the backend servers
  connection_draining         = true
  connection_draining_timeout = 300
  tags = {
    Name = "test-elb-app"
    Type = "elb"
  }
}

resource "aws_security_group" "elb" {
    name = "test-elb"
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${aws_vpc.main.id}"
    tags = {
        Name        = "test-elb-security-group"
    }
}
