# --- Region Configuration ---
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

# --- Network Configuration ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones in the region"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# --- Compute Configuration ---
variable "instance_type_master" {
  description = "Instance type for the Kubeadm Control Plane"
  type        = string
  default     = "c7i-flex.large"
}

variable "instance_type_worker" {
  description = "Instance type for Jenkins and Ansible nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}

# --- Access Configuration ---
variable "key_name" {
  description = "Name of the existing AWS SSH key pair"
  type        = string
  default     = "devops"
}

variable "GREEN" {
  description = "Color for success"
  type = string
  default = "\\033[0;32m"
}

variable "BLUE" {
  description = "color for INFO"
  type = string
  default = "\\033[0;34m"
}

variable "YELLOW" {
  description = "color for Warn"
  type = string
  default = "\\033[1;33m"
}

variable "RED" {
  description = "color for errro"
  type = string
  default = "\\033[0;31m"
}

variable "NC" {
  description = "no color"
  type = string
  default = "\\033[0m"
}
