#!/bin/bash
set -e

dnf install -y java-17-amazon-corretto-headless wget tar

# Install Kafka
wget -q "https://downloads.apache.org/kafka/${kafka_version}/kafka_2.13-${kafka_version}.tgz" -O /tmp/kafka.tgz
mkdir -p /opt/kafka
tar -xzf /tmp/kafka.tgz -C /opt/kafka --strip-components=1

# Data directory (uses root volume)
mkdir -p /data/kafka-logs

# KRaft config: this node is both broker and controller
cat > /opt/kafka/config/kraft/server.properties <<EOF
process.roles=broker,controller
node.id=${broker_id}
controller.quorum.voters=${controller_quorum_voters}
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://${broker_ip}:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
log.dirs=/data/kafka-logs
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
EOF

# Format storage and start Kafka
/opt/kafka/bin/kafka-storage.sh format -t "${cluster_id}" -c /opt/kafka/config/kraft/server.properties

cat > /etc/systemd/system/kafka.service <<EOF
[Unit]
Description=Kafka
After=network.target

[Service]
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now kafka
