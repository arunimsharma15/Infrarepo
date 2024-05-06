provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "test-server" {
  ami = "ami-080e449218d4434fa"
  instance_type = "t2.micro"
  key_name = "ec2connect"
  vpc_security_group_ids = [aws_security_group.test-sg.id]
  subnet_id = aws_subnet.test-public-subnet-01.id 

  for_each = toset(["jenkins-master", "jenkins-slave", "ansible"])

  user_data = each.key == "ansible" ? data.template_file.user_data.rendered : null

  tags = {
    Name = "${each.key}"
  }
}

data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install epel -y
    sudo yum install ansible -y
  EOF
}

resource "aws_security_group" "test-sg" {
  name        = "test-sg"
  description = "SSH Access"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ssh-prot"
  }
}

resource "aws_vpc" "test-vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "test-vpc"
  }
}

resource "aws_subnet" "test-public-subnet-01" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "test-public-subnet-01"
  }
}

resource "aws_subnet" "test-public-subnet-02" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"

  tags = {
    Name = "test-public-subnet-02"
  }
}

resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "test-igw"
  }
}

resource "aws_route_table" "test-public-rt" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw.id
  }
}

resource "aws_route_table_association" "test-rta-public-subnet-01" {
  subnet_id      = aws_subnet.test-public-subnet-01.id
  route_table_id = aws_route_table.test-public-rt.id
}

resource "aws_route_table_association" "test-rta-public-subnet-02" {
  subnet_id      = aws_subnet.test-public-subnet-02.id
  route_table_id = aws_route_table.test-public-rt.id
}