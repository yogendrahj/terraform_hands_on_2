terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.61.0"
    }
  }
}

provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}


resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_availability_zones" "available" { }

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Default subnet for eu-west-2a"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow https and ssh inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "https access"
    from_port        = 8080
    to_port          = 80808
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_instance" "jenkins_server" {
  ami           = "ami-028a5cd4ffd2ee495" # us-west-2
  instance_type = "t2.micro"
  subnet_id = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  key_name = "test_terraform_01_28092022"

  tags = {
    Name = "jenkins_server"
  }
}

resource "null_resource" "jenkins_script" {
  
  #ssh into ec2 instance

  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("D:/AWS/AWS_Credentials/test_terraform_01_28092022.pem")
    host = aws_instance.jenkins_server.public_ip
  }

  #copy the install_jenkins.sh file from local to ec2 instance

  provisioner "file" {
    source = "install_jenkins.sh"
    destinstaion = "/tmp/install_jenkins.sh"
  }

  #set permission and execute the install_jenkins.sh file

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_jenkins.sh",
      "sh /tmp/install_jenkins.sh"
    ]
  }

  depends_on = [
    aws_instance.jenkins_server
  ]

}