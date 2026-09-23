data "aws_ami" "aws_ami" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "kafka_cluster_id" {
  byte_length = 16
}

locals{
    broker_ips = [for i in range(var.broker_count) : cidrhost(local.subnet_cidrs[i], 10)]

    cluster_id = replace(random_id.kafka_cluster_id.b64_url, "=", "")

    controller_quorum_voters = join(",", [for i in range(var.broker_count) : "${i}@${local.broker_ips[i]}:9093"])
}

resource "aws_instance" "kafka-broker" {
  count         = var.broker_count

  ami           = data.aws_ami.aws_ami.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.kafka-subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.kafka-sg.id]
  private_ip   = local.broker_ips[count.index]
  iam_instance_profile = aws_iam_instance_profile.kafka_instance_profile.name
  key_name    = "var.key_name"

  depends_on = [
    aws_security_group.kafka-sg, 
    aws_subnet.kafka-subnet
    ]

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
