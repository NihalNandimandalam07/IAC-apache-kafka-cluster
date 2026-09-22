variable "aws_region" {
	type = string
    default = "us-east-2"
}

variable "vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
}

variable "availability_zones" {
    type = list(string)
    default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "broker_count" {
    type = number
    default = 3
}

variable "key_name" {
    type = string
    default = null
}



