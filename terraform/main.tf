provider "aws" {
  region = "us-east-1"
}

variable "home_cidr" {  description = "Allow SSH from this CIDR"
  default = "0.0.0.0/0"
}
variable "key_name" {
  description = "Name of key used to access the nodes"
  default = "k8s"
}

variable "num_controllers" {
  description = "The number of controller nodes you want to deploy"
  default = "3"
}

variable "num_workers" {
  description = "The number of worker nodes you want to deploy"
  default = "3"
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
  key_name = "${var.key_name}"

  count = "${var.num_controllers}"

  tags {
    Name = "controller-${count.index}"
  }
}

resource "aws_instance" "workers" {
  ami = "ami-2d39803a"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_all_between_nodes.id}", "${aws_security_group.allow_home.id}"]
  key_name = "${var.key_name}"

  count = "${var.num_workers}"

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

resource "template_file" "controller_hosts" {
  count = "${var.num_controllers}"
  template = "${file("${path.module}/hosts.tpl")}"
  vars {
    index = "${count.index}"
    name  = "controller"
    ip = "${aws_instance.controllers.*.public_ip[count.index]}"
  }
}

resource "template_file" "worker_hosts" {
  count = "${var.num_workers}"
  template = "${file("${path.module}/hosts.tpl")}"
  vars {
    index = "${count.index}"
    name  = "workers"
    ip = "${aws_instance.workers.*.public_ip[count.index]}"

  }
}

resource "template_file" "inventory" {
  template = "${file("${path.module}/inventory.tpl")}"
  vars {
    controller_hosts = "${join("\n", template_file.controller_hosts.*.rendered)}"
    worker_hosts = "${join("\n", template_file.worker_hosts.*.rendered)}"
  }
}

output "inventory" {
  value = "${template_file.inventory.rendered}"
}
