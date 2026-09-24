import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ec2,
    string
    aws_iam,
    CfnParameter,
    Aws,
    Fn,
    CfnOutput,
    CfnCondition,
)
from constructs import Construct

class CdkKafkaStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        effective_client_cidrs = CfnParameter(
            self,
            "effective_client_cidrs",
            type = string,
            default = "10.0.0.0/16"
        )


        instance_type = CfnParameter(
            self,
            "instance_type",
            type = string,
            default = "t3.medium"
        )

        vpc = aws_ec2.Vpc(
            self, 
            "kafka-vpc", 
            max_azs=3,
            ip_addresses=aws_ec2.IpAddresses.cidr("10.0.0.0/16"),
            subnet_configuration=[
                aws_ec2.SubnetConfiguration(
                    name="subnet1",
                    cidr_mask=24,
                    availability_zone="us-east-1a"
                    subnet_type=aws_ec2.SubnetType.PUBLIC
                ),
                aws_ec2.SubnetConfiguration(
                    name="subnet2",
                    cidr_mask=24,
                    availability_zone="us-east-1b"
                    subnet_type=aws_ec2.SubnetType.PUBLIC
                ),
                aws_ec2.SubnetConfiguration(
                    name="subnet3",
                    cidr_mask=24,
                    availability_zone="us-east-1c"
                    subnet_type=aws_ec2.SubnetType.PUBLIC
                )
            ]
        )

        security_group = aws_ec2.SecurityGroup(
            self,
            "kafka-security-group",
            vpc=vpc,
            allow_all_outbound=True
        )

        security_group.add_ingress_rule(
            security_group,
            connection=aws_ec2.Port.tcp(9092)
        )

        security_group.add_ingress_rule(
            security_group,
            connection=aws_ec2.Port.tcp(9093)
        )

        security_group.add_ingress_rule(
            security_group,
            peer=aws_ec2.Peer.ipv4(effective_client_cidrs.value_as_string),
            connection=aws_ec2.Port.tcp(9092)
        )


        kafka_role = aws_iam.Role(
            self,
            "kafka-role",
            assumed_by=aws_iam.ServicePrincipal("ec2.amazonaws.com"),
            managed_policies=[
                aws_iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")
            ],
        )


        subnets = vpc.public_subnets
        broker_ips = [cidr_host(subnet.ipv4_cidr_block, 10) for subnet in subnets]
        quorum_voters = ",".join(f"{i}@{ip}:9093" for i, ip in enumerate(broker_ips))
        bootstrap_servers = ",".join(f"{ip}:9092" for ip in broker_ips)


        def broker_user_data(broker_id: int, broker_ip: str) -> str:
            return f"""#!/bin/bash
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
    """    

    
    brokers = []

    for i, subnet in enumerate(subnets):
        broker = aws_ec2.Instance(
            self,
            f"kafka-broker-{i}",
            instance_type=aws_ec2.InstanceType(instance_type.value_as_string),
            machine_image=aws_ec2.MachineImage.latest_amazon_linux(),
            vpc=vpc,
            vpc_subnets=aws_ec2.SubnetSelection(subnets=[subnet]),
            security_group=security_group,
            role=kafka_role,
            private_ip_address=broker_ips[i],
            block_devices=[
                aws_ec2.BlockDevice(
                    device_name="/dev/xvda",
                    volume=aws_ec2.BlockDeviceVolume.ebs(root_volume_size.value_as_number, volume_type=aws_ec2.EbsDeviceVolumeType.GP3,
                    ),
                ),
            ],
            user_data=aws_ec2.UserData.custom(broker_user_data(i, broker_ips[i]))
        )
