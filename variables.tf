variable "vpc_subnet_ids" {
  type        = list(string)
  description = "VPC subnet IDs"
  default     = []
}

variable "tags" {
  default     = {}
  description = "Tag definition for resources"
}

variable "vpc_env" {
  description = "VPC environment name"
  type = string
}
