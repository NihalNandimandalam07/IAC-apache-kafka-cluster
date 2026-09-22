data "aws_ami" "aws_ami" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["myami-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "kafka_cluster_id" {
  byte_length = 16
}

resource "aws_instance" "kafka-broker" {
  ami           = data.aws_ami.aws_ami.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kafka-subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.kafka-sg.id]
  private_ip   = local.broker_ips[count.index]
  key_name    = "var.key_name"

  tags = {
    Name = "kafka-broker-${count.index}"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    broker_id = count.index
    broker_ip = local.broker_ips[count.index]
    cluster_id = local.cluster_id
    controller_quorum_voters = local.controller_quorum_voters
    kafka_version = var.kafka_version
  })

  tags = {
    Name = "kafka-broker-${count.index}"
  }
}