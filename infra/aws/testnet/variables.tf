variable "name" {
  description = "Base name for the Scuro testnet stack."
  type        = string
  default     = "scuro-testnet"
}

variable "region" {
  description = "AWS region for the testnet."
  type        = string
}

variable "availability_zone" {
  description = "Single AZ to use for the private subnet."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the private VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the single private subnet."
  type        = string
  default     = "10.42.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the single host runtime."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 40
}

variable "bucket_force_destroy" {
  description = "Whether the artifact bucket may be destroyed with objects in it."
  type        = bool
  default     = false
}

variable "runtime_env_parameter_name" {
  description = "Optional SecureString SSM parameter containing newline-delimited runtime env vars."
  type        = string
  default     = ""
}

variable "enable_cloudwatch_logs" {
  description = "Whether to enable CloudWatch log shipping resources for the host."
  type        = bool
  default     = false
}

variable "enable_sqs_queue" {
  description = "Whether to provision the async proof SQS queue and endpoint."
  type        = bool
  default     = false
}

variable "enable_public_rpc" {
  description = "Whether to expose public RPC through CloudFront and a host proxy."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra resource tags."
  type        = map(string)
  default     = {}
}
