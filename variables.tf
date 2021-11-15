# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "stacker_namespace" {
  description = "The name of the datacenter"
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

variable "sgs_state_path" {
  description = "The state path for security groups"
}

variable "workspace" {
  description = "terraform workspace"
  type        = string
}

variable "stack" {
  description = "The stack Spinnaker is running in."
  default     = ""
  type        = string
}

variable "mcp_account" {
  description = "If MCP account, set permissions boundary"
  default     = false
  type        = bool
}

variable "permissions_boundary" {
  description = "If an MCP account, this is the permissions boundary ARN"
  default     = ""
  type        = string
}

variable "moniker_service_id" {
  default     = "PLANGRID"
  description = "Service ID according to Autodesk (must be all uppercase)"
  type        = string
}

variable "moniker_env" {
  description = "Single character Environment ID (P = Production, S = Staging, C = Development)"
  type        = string
}

variable "moniker_region_id" {
  description = "3 character Region ID according to https://wiki.autodesk.com/display/DOJO/AWS+Region+Standard+Abbreviations"
  type        = string
}

variable "cluster_name" {
  description = "The name of the eks cluster (e.g. eks-prod). This is used to namespace all the resources created by these templates."
  type        = string
}

variable "pipelayer_settings" {
  description = "The url of pipelayer to send spinnaker data - default is dev"
  default = {
    pipelayer_url    = "https://pipelayer.auto-internal.dev-use1-pg-1.us-east-1.rnd.planfront.net/spinnaker/"
    enable_pipelayer = false
  }
  type = object({
    pipelayer_url    = string
    enable_pipelayer = bool
  })
}

variable "spinnaker_version" {
  default = "1.20.8"
}

variable "slack_settings" {
  type = object({
    enabled = bool
    token   = string
  })
  default = {
    enabled = false
    token   = "secret"
  }
}

variable "istio_gateway_tag" {
  description = "Tag used for istio gateway"
  type        = string
  default     = "1_7_8"
}

variable "istio_image_hub" {
  type    = string
  default = "723151894364.dkr.ecr.us-east-1.amazonaws.com/pg-istio"
}

variable "gateway_hpa_max_replicas" {
  type    = number
  default = 5
}

variable "gateway_hpa_min_replicas" {
  type    = number
  default = 2
}

variable "spinnaker_aws_role_arn" {
  type = string
}

variable "gcr_docker_registry" {
  type = object({
    enabled      = bool
    gcr_password = string
  })
  default = {
    enabled      = false
    gcr_password = <<EOT
        <SECRET>
      EOT
  }
}

variable "planfront_url" {
  type        = string
  description = "base url for the datacenter, spinnaker with use to maker spinnaker.planfront_url"
}

variable "internal_gateway_cert_arn" {
  type = string
}

variable "spinnaker_s3_buckets" {
  type = object({
    front50_bucket = string
    kayenta_bucket = string
  })
}

variable "newrelic_kayenta_settings" {
  type = object({
    api_key           = string
    application_key   = string
    account_name      = string
    enable_nr_kayenta = bool
  })

  default = {
    api_key           = "secret"
    application_key   = "secret"
    account_name      = "plangrid-newrelic"
    enable_nr_kayenta = false
  }
}

variable "datadog_settings" {
  type = object({
    api_key                     = string
    application_key             = string
    base_url                    = string
    account_name                = string
    enable_spinnaker_metrics    = bool
    enable_kayenta_metric_store = bool
  })

  default = {
    api_key                     = "secretKey"
    application_key             = "secretKey"
    base_url                    = "https://api.datadoghq.com"
    account_name                = "plangrid"
    enable_spinnaker_metrics    = false
    enable_kayenta_metric_store = false
  }
}


variable "spinnaker_saml_settings" {
  type = object({
    enabled           = bool
    issuerId          = string
    keyStore          = string
    keyStoreAliasName = string
    keyStorePassword  = string
    metadataLocal     = string
    serviceAddress    = string
  })
  default = {
    "enabled"           = false
    "issuerId"          = "net.planfront:dev-usw2-sp-1"
    "keyStore"          = "saml.jks"
    "keyStoreAliasName" = "saml"
    "keyStorePassword"  = "changeMe"
    "metadataLocal"     = "okta-metadata.xml"
    "serviceAddress"    = "https://spinnaker.dev-usw2-dpe-1.us-west-2.dped.planfront.net/gate"
  }
}

variable "spinnaker_saml_files" {
  type = object({
    keystore = string
    metadata = string
  })
  default = {
    keystore = <<EOT
        <SECRET>
      EOT
    metadata = <<EOT
          <SECRET>
      EOT
  }
}

variable "jenkins_enabled" {
  type    = bool
  default = false
}

variable "jenkins_settings" {
  type = object({
    address  = string
    name     = string
    password = string
    username = string
  })

  default = {
    "address"  = "https://jenkins-internal.planfront.net/"
    "name"     = "jenkins.planfront.net"
    "password" = "Secret"
    "username" = "Secret"
  }
}

variable "gcr_pubsub_settings" {
  type = object({
    subscriptionName       = string
    enabled                = bool
    pubsub_creds_json_file = string
  })
  default = {
    "subscriptionName"       = "spinnaker-dev-usw2-dpe-1"
    "enabled"                = false
    "pubsub_creds_json_file" = <<EOT
          <SECRET>
      EOT
  }
}

variable "local_cluster_kubeconfig" {
  type    = string
  default = <<EOT
          <SECRET>
    EOT
}

variable "force_conflicts" {
  default     = false
  description = "Force apply manifests even if conflicts (usually from manually editing manifests) FOR DEV ENVS ONLY"
  type        = bool
}

variable "elasticache_instance_class" {
  description = "Size of the RDS database supporting Spinnaker"
  type        = string
  default     = "cache.m3.large"
}

variable "rds_instance_class" {
  description = "Size of the RDS database supporting Spinnaker"
  type        = string
  default     = "db.t3.large"
}

variable "eks_worker_role_arn" {
  description = "ARN for the EKS worker role that Spinnaker is provisioned in"
  type        = string
}

variable "kms_parameter_store_key_arn" {
  description = "ARN for the KMS key used by parameter store"
  type        = string
}