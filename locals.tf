locals{
    subnet_cidr = [for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i)]

    broker_ips = [for i in range(var.broker_count) : cidrhost(local.subnet_cidr[i], 10)]

    controller_voters = [
        for i in range(var.broker_count) : 
        "${i}@${local.broker_ips[i]}:9093"
        ]
    
    controller_quorum_voters = join(",", local.controller_voters)
}