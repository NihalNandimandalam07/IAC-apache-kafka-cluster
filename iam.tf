resource "aws_iam_role" "kafka_role" {
  name_prefix = "kafka-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.kafka_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
} 

resource "aws_iam_instance_profile" "kafka_instance_profile" {
  name_prefix = "kafka-"
  role        = aws_iam_role.kafka_role.name
}
