variable "aws_region" {
  description = "Region for the VPC"
  default = "us-east-2"
}

variable "public_subnet_az" {
  description = "AZ for the VPC"
  default = "us-east-2a"
}

variable "private_subnet_az" {
  description = "AZ for the VPC"
  default = "us-east-2b"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet"
  default = "10.0.2.0/24"
}

variable "ami" {
  description = "Ubuntu Server 18.04 LTS"
  default = "ami-02f706d959cedf892"
}

variable "key_path" {
  description = "SSH Public Key path"
  default = "/home/ec2-user/.ssh/id_rsa.pub"
}

variable "instance_type" {
  description = "Type of instance"
  default = "t2.micro"
}
