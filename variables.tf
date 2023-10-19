variable "vpc_subnet_ids" {
  type        = list(string)
  description = "VPC subnet IDs"
  default     = []
}

variable "vpc_env" {
  description = "VPC environment name"
  type        = string
}
