locals {
  effective_client_cidrs = length(var.client_access_cidrs) > 0 ? var.client_access_cidrs : [var.vpc_cidr]
}

resource "aws_security_group" "kafka-sg" {
    name_prefix        = "kafka-"
    vpc_id = aws_vpc.kafka-vpc.id

    depends_on = [aws_vpc.kafka-vpc]

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = local.effective_client_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kafka-sg"
  } 
  
}

