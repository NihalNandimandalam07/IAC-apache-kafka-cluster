resource "random_password" "kafka_password"{
    length = 18
    special = false
}

resource "aws_secretsmanager_secret" "kafka_secret"{
    name = "kafka_credentials"
    tags = {
        Name = "kafka-credentials"
    }
}

resource "aws_secretsmanager_secret_version" "kafka_secret_version" {
    secret_id     = aws_secretsmanager_secret.kafka_secret.id
    secret_string = jsonencode({
        username = "kafka_broker"
        password = random_password.kafka_password.result
    })

    depends_on = [
        aws_secretsmanager_secret.kafka_secret
    ]
}


resource "aws_iam_role_policy" "kafka_secrets_policy" {
    name = "kafka-secrets-policy"
    role = aws_iam_role.kafka_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ]
                Resource = aws_secretsmanager_secret.kafka_secret.arn
            }
        ]
    })
}