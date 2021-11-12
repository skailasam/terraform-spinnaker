########################
# ADSK Tags
########################
module "adsk_tags" {
  source             = "git::git@github.com:plangrid/tf-adsk-tags.git?ref=0.13upgrade"
  workspace          = var.workspace
  moniker_service_id = var.moniker_service_id
  moniker_env        = var.moniker_env
  moniker_region_id  = var.moniker_region_id
  environment        = var.stack
  tags               = {}
}

########################
# Spinnaker Redis
########################
# Redis auth_token
resource "random_string" "redis_auth_token" {
  length = 30
}

resource "aws_ssm_parameter" "ssm_REDIS_conn_string" {
  name        = "/dc/${var.workspace}/regional-settings/${var.stack}/infra/settings/${var.cluster_name}/REDIS_CONN_STRING"
  description = "Connection string to connect to the Redis Elasticache cluster"
  type        = "SecureString"
  key_id      = var.kms_parameter_store_key_arn
  value = format(
    "redis://%s@%s:%s",
    random_string.redis_auth_token.result,
    module.redis.endpoint,
    module.redis.port,
  )
  overwrite = true
  tags      = module.adsk_tags.tags
}

# Create Elasticache (Redis) for Spinnaker
module "redis" {
  source = "github.com/terraform-community-modules/tf_aws_elasticache_redis.git?ref=v2.4.0"

  env              = var.stack
  redis_version    = "6.x"
  redis_node_type  = var.elasticache_instance_class
  name             = "${local.name}-redis"
  redis_clusters   = "2"
  redis_failover   = "true"
  multi_az_enabled = "true"

  availability_zones   = data.terraform_remote_state.vpc.outputs.availability_zones
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  subnets              = [data.terraform_remote_state.vpc.outputs.elasticache_subnet_group]
  security_group_names = [data.terraform_remote_state.security_groups.outputs.internal_redis_sg]

  apply_immediately              = "true"
  auth_token                     = random_string.redis_auth_token.result
  at_rest_encryption_enabled     = "true"
  transit_encryption_enabled     = "true"
  redis_snapshot_retention_limit = "5"

  redis_parameters = [{
    name  = "min-slaves-max-lag"
    value = "5"
    }, {
    name  = "min-slaves-to-write"
    value = "1"
    }, {
    name  = "databases"
    value = "32"
  }]

  tags = module.adsk_tags.tags
}

########################
# Spinnaker S3 bucket
########################
resource "aws_s3_bucket" "spinnaker_bucket" {
  bucket = local.name
  acl    = "private"
  tags   = module.adsk_tags.tags

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # We add this to make destroys of this module not depend on the bucket being empty
  force_destroy = true
}

resource "aws_s3_bucket_policy" "spinnaker_bucket_policy" {
  bucket = aws_s3_bucket.spinnaker_bucket.id
  policy = data.aws_iam_policy_document.spinnaker_bucket_deny_insecure_transport.json
}

data "aws_iam_policy_document" "spinnaker_bucket_deny_insecure_transport" {
  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.spinnaker_bucket.arn,
      "${aws_s3_bucket.spinnaker_bucket.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}

########################
# Spinnaker MYSQL Database
########################
# MYSQL master_password
resource "random_string" "rds_password" {
  length  = 30
  special = false
}

resource "aws_ssm_parameter" "ssm_rds_conn_string" {
  name        = "/dc/${var.workspace}/regional-settings/${var.stack}/infra/settings/${var.cluster_name}/RDS_CONN_STRING"
  description = "Connection string to connect as the owner user for the Spinnaker MYSQL RDS database"
  type        = "SecureString"
  key_id      = var.kms_parameter_store_key_arn
  value = format(
    "mysqlx://owner:%s@%s:3306/%s",
    random_string.rds_password.result,
    module.db.db_instance_address,
    module.db.db_instance_name,
  )
  overwrite = true
  tags      = module.adsk_tags.tags
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier = "${local.name}-rds-mysql"

  engine         = "mysql"
  engine_version = "8.0.26"
  # DB parameter group
  family = "mysql8.0"
  # DB option group
  major_engine_version = "8.0"

  # instance settings
  apply_immediately     = true
  instance_class        = var.rds_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  skip_final_snapshot   = true
  storage_encrypted     = true
  storage_type          = "gp2"

  # backup settings
  backup_window           = "01:00-03:00"
  maintenance_window      = "sat:00:00-sat:00:30"
  backup_retention_period = 30

  # database connection settings
  # username and password must not be set for replicas.
  username                            = "owner"
  password                            = random_string.rds_password.result
  port                                = 3306
  iam_database_authentication_enabled = true

  # monitoring settings
  monitoring_interval                   = 10
  monitoring_role_name                  = "SpinnakerRDSMonitoringRole"
  create_monitoring_role                = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # networking settings
  multi_az             = true
  publicly_accessible  = false
  subnet_ids           = data.terraform_remote_state.vpc.outputs.private_subnets
  db_subnet_group_name = data.terraform_remote_state.vpc.outputs.database_subnet_group
  vpc_security_group_ids = compact(
    [
      module.sg_mysql.this_security_group_id,
    ],
  )

  # other options include audit, error, slowquery if enabled via the parameter group
  enabled_cloudwatch_logs_exports = ["general"]

  tags = module.adsk_tags.tags
}

/*
 Security group for the RDS DB to allow mysql-tcp (3306) ingress.
 TODO: Look into locking this down to just the CIDRs of the EKS cluster hosting Spinnaker
*/
module "sg_mysql" {
  source = "git::git@github.com:plangrid/tf-sgs.git//modules/security-group?ref=v1.22.0"
  create = true
  name   = local.name
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  tags   = module.adsk_tags.tags

  ingress_with_self = [
    {
      rule = "mysql-tcp"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

