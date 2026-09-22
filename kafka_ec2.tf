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

resource "aws_instance" "kafka-broker" {
  ami           = data.aws_ami.aws_ami.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.kafka-subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.kafka-sg.id]
  private_ip   = each.value.ip
  key_name    = "var.key_name"

  tags = {
    Name = "kafka-broker-${count.index + 1}"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

/*  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = var.data_volume_size
    volume_type = "gp3"
  } */

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    broker_id = count.index
    broker_ip = local.broker_ips[count.index]
    cluster_id = local.cluster_id
    kafka_version = var.kafka_version
  })

  tags = {
    Name = "kafka-broker-${count.index + 1}"
  }
}