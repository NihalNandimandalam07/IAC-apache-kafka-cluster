#!/bin/bash
# Installs and starts a single-node Apache Kafka cluster in KRaft mode (broker + controller on one host).
# Rendered by Terraform templatefile(); values are injected below.
set -euxo pipefail

dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent

KAFKA_VERSION="${kafka_version}"
SCALA_VERSION="2.13"
CLUSTER_ID="${cluster_id}"
HEAP_SIZE="${heap_size}"

#added
SECRET_ARN="${secret_arn}"

KAFKA_DIST="kafka_$SCALA_VERSION-$KAFKA_VERSION"


IMDS_TOKEN=$(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PRIVATE_IP=$(curl -fsS -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)


dnf install -y java-21-amazon-corretto-headless shadow-utils tar gzip awscli

id kafka >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin kafka

#added
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text)
KAFKA_USERNAME=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
KAFKA_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")

#added
test -n "$KAFKA_USERNAME"
test -n "$KAFKA_PASSWORD"

curl -fsSL --retry 5 -o "/tmp/$KAFKA_DIST.tgz" "https://dlcdn.apache.org/kafka/$KAFKA_VERSION/$KAFKA_DIST.tgz" \
  || curl -fsSL --retry 5 -o "/tmp/$KAFKA_DIST.tgz" "https://archive.apache.org/dist/kafka/$KAFKA_VERSION/$KAFKA_DIST.tgz"
tar -xzf "/tmp/$KAFKA_DIST.tgz" -C /opt
rm -f "/tmp/$KAFKA_DIST.tgz"
ln -sfn "/opt/$KAFKA_DIST" /opt/kafka

mkdir -p /etc/kafka /var/lib/kafka/data /var/log/kafka


cat > /etc/kafka/server.properties <<EOF
process.roles=broker,controller
node.id=${broker_id}
controller.quorum.voters=${controller_quorum_voters}

listeners=SASL_PLAINTEXT://0.0.0.0:9092,CONTROLLER://$PRIVATE_IP:9093,INTERNAL://$PRIVATE_IP:9094
advertised.listeners=SASL_PLAINTEXT://$PRIVATE_IP:9092,INTERNAL://$PRIVATE_IP:9094
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT,CONTROLLER:PLAINTEXT,INTERNAL:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=INTERNAL

sasl.enabled.mechanisms=PLAIN

listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$KAFKA_USERNAME" password="$KAFKA_PASSWORD" user_$KAFKA_USERNAME="$KAFKA_PASSWORD";

log.dirs=/var/lib/kafka/data
num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
auto.create.topics.enable=false
log.retention.hours=168
EOF

cat > /etc/kafka/client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$KAFKA_USERNAME" password="$KAFKA_PASSWORD";
EOF

#added
chown kafka:kafka /etc/kafka/server.properties
chmod 600 /etc/kafka/server.properties

chown kafka:kafka /etc/kafka/client.properties
chmod 600 /etc/kafka/client.properties

/opt/kafka/bin/kafka-storage.sh format --ignore-formatted \
  --cluster-id "$CLUSTER_ID" \
  --config /etc/kafka/server.properties

chown -R kafka:kafka "/opt/$KAFKA_DIST" /etc/kafka /var/lib/kafka /var/log/kafka

cat > /etc/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka (KRaft)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kafka
Group=kafka
Environment="KAFKA_HEAP_OPTS=-Xms$HEAP_SIZE -Xmx$HEAP_SIZE"
Environment="LOG_DIR=/var/log/kafka"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kafka