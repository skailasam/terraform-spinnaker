## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.64.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.6.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_adsk_tags"></a> [adsk\_tags](#module\_adsk\_tags) | git::git@github.com:plangrid/tf-adsk-tags.git | 0.13upgrade |
| <a name="module_db"></a> [db](#module\_db) | terraform-aws-modules/rds/aws | ~> 3.0 |
| <a name="module_redis"></a> [redis](#module\_redis) | github.com/terraform-community-modules/tf_aws_elasticache_redis.git | v2.4.0 |
| <a name="module_sg_mysql"></a> [sg\_mysql](#module\_sg\_mysql) | git::git@github.com:plangrid/tf-sgs.git//modules/security-group | v1.22.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.spinnaker-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.spinnaker-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.spinnaker-policy-attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.spinnaker_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.spinnaker_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_ssm_parameter.ssm_REDIS_conn_string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ssm_rds_conn_string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [kubernetes_manifest.spinnaker-ingress-gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.spinnaker-istio-gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.spinnaker-virtual-service](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [null_resource.spinnaker-service-manifest-apply](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.rds_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.redis_auth_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.spinnaker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.spinnaker_bucket_deny_insecure_transport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.worker_iam_role_assume_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [terraform_remote_state.security_groups](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.vpc](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region in which all resources will be created | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the eks cluster (e.g. eks-prod). This is used to namespace all the resources created by these templates. | `string` | n/a | yes |
| <a name="input_datadog_settings"></a> [datadog\_settings](#input\_datadog\_settings) | n/a | <pre>object({<br>    api_key                     = string<br>    application_key             = string<br>    base_url                    = string<br>    account_name                = string<br>    enable_spinnaker_metrics    = bool<br>    enable_kayenta_metric_store = bool<br>  })</pre> | <pre>{<br>  "account_name": "plangrid",<br>  "api_key": "secretKey",<br>  "application_key": "secretKey",<br>  "base_url": "https://api.datadoghq.com",<br>  "enable_kayenta_metric_store": false,<br>  "enable_spinnaker_metrics": false<br>}</pre> | no |
| <a name="input_eks_worker_role_arn"></a> [eks\_worker\_role\_arn](#input\_eks\_worker\_role\_arn) | ARN for the EKS worker role that Spinnaker is provisioned in | `string` | n/a | yes |
| <a name="input_elasticache_instance_class"></a> [elasticache\_instance\_class](#input\_elasticache\_instance\_class) | Size of the RDS database supporting Spinnaker | `string` | `"cache.m3.large"` | no |
| <a name="input_force_conflicts"></a> [force\_conflicts](#input\_force\_conflicts) | Force apply manifests even if conflicts (usually from manually editing manifests) FOR DEV ENVS ONLY | `bool` | `false` | no |
| <a name="input_gateway_hpa_max_replicas"></a> [gateway\_hpa\_max\_replicas](#input\_gateway\_hpa\_max\_replicas) | n/a | `number` | `5` | no |
| <a name="input_gateway_hpa_min_replicas"></a> [gateway\_hpa\_min\_replicas](#input\_gateway\_hpa\_min\_replicas) | n/a | `number` | `2` | no |
| <a name="input_gcr_docker_registry"></a> [gcr\_docker\_registry](#input\_gcr\_docker\_registry) | n/a | <pre>object({<br>    enabled      = bool<br>    gcr_password = string<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "gcr_password": "        <SECRET>\n"<br>}</pre> | no |
| <a name="input_gcr_pubsub_settings"></a> [gcr\_pubsub\_settings](#input\_gcr\_pubsub\_settings) | n/a | <pre>object({<br>    subscriptionName       = string<br>    enabled                = bool<br>    pubsub_creds_json_file = string<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "pubsub_creds_json_file": "          <SECRET>\n",<br>  "subscriptionName": "spinnaker-dev-usw2-dpe-1"<br>}</pre> | no |
| <a name="input_internal_gateway_cert_arn"></a> [internal\_gateway\_cert\_arn](#input\_internal\_gateway\_cert\_arn) | n/a | `string` | n/a | yes |
| <a name="input_istio_gateway_tag"></a> [istio\_gateway\_tag](#input\_istio\_gateway\_tag) | Tag used for istio gateway | `string` | `"1_7_8"` | no |
| <a name="input_istio_image_hub"></a> [istio\_image\_hub](#input\_istio\_image\_hub) | n/a | `string` | `"723151894364.dkr.ecr.us-east-1.amazonaws.com/pg-istio"` | no |
| <a name="input_jenkins_enabled"></a> [jenkins\_enabled](#input\_jenkins\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_jenkins_settings"></a> [jenkins\_settings](#input\_jenkins\_settings) | n/a | <pre>object({<br>    address  = string<br>    name     = string<br>    password = string<br>    username = string<br>  })</pre> | <pre>{<br>  "address": "https://jenkins-internal.planfront.net/",<br>  "name": "jenkins.planfront.net",<br>  "password": "Secret",<br>  "username": "Secret"<br>}</pre> | no |
| <a name="input_kms_parameter_store_key_arn"></a> [kms\_parameter\_store\_key\_arn](#input\_kms\_parameter\_store\_key\_arn) | ARN for the KMS key used by parameter store | `string` | n/a | yes |
| <a name="input_local_cluster_kubeconfig"></a> [local\_cluster\_kubeconfig](#input\_local\_cluster\_kubeconfig) | n/a | `string` | `"          <SECRET>\n"` | no |
| <a name="input_mcp_account"></a> [mcp\_account](#input\_mcp\_account) | If MCP account, set permissions boundary | `bool` | `false` | no |
| <a name="input_moniker_env"></a> [moniker\_env](#input\_moniker\_env) | Single character Environment ID (P = Production, S = Staging, C = Development) | `string` | n/a | yes |
| <a name="input_moniker_region_id"></a> [moniker\_region\_id](#input\_moniker\_region\_id) | 3 character Region ID according to https://wiki.autodesk.com/display/DOJO/AWS+Region+Standard+Abbreviations | `string` | n/a | yes |
| <a name="input_moniker_service_id"></a> [moniker\_service\_id](#input\_moniker\_service\_id) | Service ID according to Autodesk (must be all uppercase) | `string` | `"PLANGRID"` | no |
| <a name="input_newrelic_kayenta_settings"></a> [newrelic\_kayenta\_settings](#input\_newrelic\_kayenta\_settings) | n/a | <pre>object({<br>    api_key           = string<br>    application_key   = string<br>    account_name      = string<br>    enable_nr_kayenta = bool<br>  })</pre> | <pre>{<br>  "account_name": "plangrid-newrelic",<br>  "api_key": "secret",<br>  "application_key": "secret",<br>  "enable_nr_kayenta": false<br>}</pre> | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | If an MCP account, this is the permissions boundary ARN | `string` | `""` | no |
| <a name="input_pipelayer_settings"></a> [pipelayer\_settings](#input\_pipelayer\_settings) | The url of pipelayer to send spinnaker data - default is dev | <pre>object({<br>    pipelayer_url    = string<br>    enable_pipelayer = bool<br>  })</pre> | <pre>{<br>  "enable_pipelayer": false,<br>  "pipelayer_url": "https://pipelayer.auto-internal.dev-use1-pg-1.us-east-1.rnd.planfront.net/spinnaker/"<br>}</pre> | no |
| <a name="input_planfront_url"></a> [planfront\_url](#input\_planfront\_url) | base url for the datacenter, spinnaker with use to maker spinnaker.planfront\_url | `string` | n/a | yes |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | Size of the RDS database supporting Spinnaker | `string` | `"db.t3.large"` | no |
| <a name="input_sgs_state_path"></a> [sgs\_state\_path](#input\_sgs\_state\_path) | The state path for security groups | `any` | n/a | yes |
| <a name="input_slack_settings"></a> [slack\_settings](#input\_slack\_settings) | n/a | <pre>object({<br>    enabled = bool<br>    token   = string<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "token": "secret"<br>}</pre> | no |
| <a name="input_spinnaker_aws_role_arn"></a> [spinnaker\_aws\_role\_arn](#input\_spinnaker\_aws\_role\_arn) | n/a | `string` | n/a | yes |
| <a name="input_spinnaker_s3_buckets"></a> [spinnaker\_s3\_buckets](#input\_spinnaker\_s3\_buckets) | n/a | <pre>object({<br>    front50_bucket = string<br>    kayenta_bucket = string<br>  })</pre> | n/a | yes |
| <a name="input_spinnaker_saml_files"></a> [spinnaker\_saml\_files](#input\_spinnaker\_saml\_files) | n/a | <pre>object({<br>    keystore = string<br>    metadata = string<br>  })</pre> | <pre>{<br>  "keystore": "        <SECRET>\n",<br>  "metadata": "          <SECRET>\n"<br>}</pre> | no |
| <a name="input_spinnaker_saml_settings"></a> [spinnaker\_saml\_settings](#input\_spinnaker\_saml\_settings) | n/a | <pre>object({<br>    enabled           = bool<br>    issuerId          = string<br>    keyStore          = string<br>    keyStoreAliasName = string<br>    keyStorePassword  = string<br>    metadataLocal     = string<br>    serviceAddress    = string<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "issuerId": "net.planfront:dev-usw2-sp-1",<br>  "keyStore": "saml.jks",<br>  "keyStoreAliasName": "saml",<br>  "keyStorePassword": "changeMe",<br>  "metadataLocal": "okta-metadata.xml",<br>  "serviceAddress": "https://spinnaker.dev-usw2-dpe-1.us-west-2.dped.planfront.net/gate"<br>}</pre> | no |
| <a name="input_spinnaker_version"></a> [spinnaker\_version](#input\_spinnaker\_version) | n/a | `string` | `"1.20.8"` | no |
| <a name="input_stack"></a> [stack](#input\_stack) | The stack Spinnaker is running in. | `string` | `""` | no |
| <a name="input_stacker_namespace"></a> [stacker\_namespace](#input\_stacker\_namespace) | The name of the datacenter | `string` | n/a | yes |
| <a name="input_tfstate_global_bucket"></a> [tfstate\_global\_bucket](#input\_tfstate\_global\_bucket) | The Terraform state bucket. | `string` | n/a | yes |
| <a name="input_tfstate_global_bucket_region"></a> [tfstate\_global\_bucket\_region](#input\_tfstate\_global\_bucket\_region) | The Terraform state bucket region. | `string` | n/a | yes |
| <a name="input_vpc_state_path"></a> [vpc\_state\_path](#input\_vpc\_state\_path) | The path in the bucket with the VPC state | `string` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | terraform workspace | `string` | n/a | yes |

## Outputs

