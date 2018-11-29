variable "aws_region" {}

variable "owner_tag" {}

variable "ttl_tag" {}

variable "ami_id" {}

variable "instance_type" {}

variable "ssh_key_name" {}

variable "name_prefix" {}

variable "user_data" {}

variable "iam_instance_profile_name" {
  default = ""
}

output "ip" {
  value = "${aws_instance.ubuntu.public_ip}"
}

output "sg_id" {
  value = "${module.security.security_group_id}"
}
