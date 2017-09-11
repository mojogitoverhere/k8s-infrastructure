provider "aws" {
  region = "us-east-1"
}

variable "sg_port" {
  type = "string"
  description = "Security group port"
  default = 8080
}

variable "home_cidr" {
  type = "string"
  description = "Allow SSH from this CIDR"
  default = "0.0.0.0/0"
}

resource "aws_vpc" "k8s" {
  cidr_block = "10.10.0.0/16"

  tags {
    Name = "k8s"
  }
}

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.k8s.id}"
  cidr_block = "10.10.0.0/24"

  tags {
    Name = "public"
  }
}

resource "aws_instance" "controllers" {
  ami = "ami-2d39803a"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_all_between_nodes.id}", "${aws_security_group.allow_home.id}"]

  count = 3

  tags {
    Name = "controller-${count.index}"
  }
}

resource "aws_instance" "workers" {
  ami = "ami-2d39803a"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_all_between_nodes.id}", "${aws_security_group.allow_home.id}"]

  count = 3

  tags {
    Name = "worker-${count.index}"
  }
}

resource "aws_eip" "eip" {
  vpc = true
}

resource "aws_security_group" "allow_home" {
  name = "allow_home"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.home_cidr}"]
  }
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["${var.home_cidr}"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.home_cidr}"]
  }
}

resource "aws_security_group" "allow_all_between_nodes" {
  name = "allow_all_between_nodes"

  ingress {
    self = true
    protocol = -1
    from_port = 0
    to_port = 0
  }
}

resource "null_resource" "inventory" {
  provisioner "local-exec" {
    command = "echo 'hello' > test.txt"
  }
}