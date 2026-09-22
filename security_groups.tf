resource "aws_security_group" "kafka-sg" {
    name_prefix        = "kafka-"
    vpc_id = aws_vpc.kafka-vpc.id

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

/* ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [""]
    self = true
  } */

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

