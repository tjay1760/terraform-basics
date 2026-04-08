variable "server_port" {
  description = "Port number for requests"
  type        = number
  default     = 8080
}
variable "ssh_port" {
description = "Port number for ssh"
type = number
default = 22  
}
variable "egress_port" {
    description = "egress port"
    type=number
    default=0
  
}
variable "instance_type" {
  description = "the instance type to be used"
  type        = string
  default     = "t3.micro"
}