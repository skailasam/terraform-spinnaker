# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "tfstate_global_bucket" {
  description = "The Terraform state bucket."
  type        = string
}

variable "tfstate_global_bucket_region" {
  description = "The Terraform state bucket region."
  type        = string
}

variable "vpc_state_path" {
  description = "The path in the bucket with the VPC state"
  type        = string
}

variable "cluster_name" {
  description = "The name of the eks cluster (e.g. eks-prod). This is used to namespace all the resources created by these templates."
  type        = string
}