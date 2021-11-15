###########################################
# Local module variables
###########################################
locals {
  # sanitize to make sure we don't fat finger underscores
  name = replace(replace(format("%.18s-%s", var.cluster_name, var.stack), "_", "-"), "[^a-z0-9-]+", "")

  # ADSK IAM restrictions that need to be enforced.
  permissions_boundary = var.mcp_account ? (var.permissions_boundary == "" ? format(
    "arn:aws:iam::%s:policy/ADSK-Boundary",
    data.aws_caller_identity.current.account_id,
  ) : var.permissions_boundary) : ""
}

data "aws_caller_identity" "current" {}

###########################################
# Remote state for VPC
###########################################
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.tfstate_global_bucket
    key    = "${var.vpc_state_path}/terraform.tfstate"
    region = var.tfstate_global_bucket_region
  }
}

###########################################
# Remote state for Security Groups
###########################################
data "terraform_remote_state" "security_groups" {
  backend = "s3"

  config = {
    bucket = var.tfstate_global_bucket
    key    = "${var.sgs_state_path}/terraform.tfstate"
    region = var.tfstate_global_bucket_region
  }
}

###########################################
# Kubernetes Provider
###########################################
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_manifest" "spinnaker-istio-gateway" {
  manifest = {
    "apiVersion" = "install.istio.io/v1alpha1"
    "kind"       = "IstioOperator"
    "metadata" = {
      "name"      = "spinnaker-gateway"
      "namespace" = "istio-system"
    }
    "spec" = {
      "components" = {
        "egressGateways" = [
          {
            "enabled" = false
            "name"    = "istio-egressgateway"
          },
        ]
        "ingressGateways" = [
          {
            "enabled" = false
            "name"    = "istio-ingressgateway"
          },
          {
            "enabled" = true
            "k8s" = {
              "affinity" = {
                "podAntiAffinity" = {
                  "preferredDuringSchedulingIgnoredDuringExecution" = [
                    {
                      "podAffinityTerm" = {
                        "labelSelector" = {
                          "matchExpressions" = [
                            {
                              "key"      = "istio"
                              "operator" = "In"
                              "values" = [
                                "ingressgateway-spinnaker-internal",
                              ]
                            },
                          ]
                        }
                        "topologyKey" = "kubernetes.io/hostname"
                      }
                      "weight" = 100
                    },
                  ]
                }
              }
              "hpaSpec" = {
                "maxReplicas" = var.gateway_hpa_max_replicas
                "minReplicas" = var.gateway_hpa_min_replicas
              }
              "podAnnotations" = {
                "pg_app" = "istio-ingress-spinnaker"
              }
              "priorityClassName" = "system-cluster-critical"
              "replicaCount"      = var.gateway_hpa_max_replicas
              "resources" = {
                "requests" = {
                  "cpu"    = "800m"
                  "memory" = "512Mi"
                }
              }
              "service" = {
                "ports" = [
                  {
                    "name"       = "http"
                    "port"       = "80"
                    "targetPort" = 8080
                  },
                  {
                    "name"       = "https"
                    "port"       = 443
                    "targetPort" = 8443
                  },
                ]
                "type" = "LoadBalancer"
              }
              "serviceAnnotations" = {
                "pg_app"                                                              = "istio-ingress-spinnaker"
                "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"       = "http"
                "service.beta.kubernetes.io/aws-load-balancer-internal"               = "true"
                "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"               = var.internal_gateway_cert_arn
                "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS-1-2-2017-01"
                "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"              = "443"
                "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"              = "443"
                "external-dns.alpha.kubernetes.io/hostname"                           = "spinnaker.${var.planfront_url}"
                "external-dns.alpha.kubernetes.io/ttl"                                = "300"
              }
            }
            "label" = {
              "app"   = "ingressgateway-spinnaker"
              "color" = "green"
              "istio" = "ingressgateway-spinnaker-internal"
            }
            "name"      = "istio-ingressgateway-spinnaker-internal"
            "namespace" = "istio-system"
          },
        ]
      }
      "hub"     = "${var.istio_image_hub}"
      "profile" = "empty"
      "tag"     = "${var.istio_gateway_tag}"
      "values" = {
        "gateways" = {
          "istio-ingressgateway" = {
            "name" = "istio-ingressgateway-spinnaker-internal"
            "secretVolumes" = [
              {
                "mountPath"  = "/etc/istio/ilbgateway-certs"
                "name"       = "ilbgateway-certs"
                "secretName" = "istio-ilbgateway-certs"
              },
              {
                "mountPath"  = "/etc/istio/ilbgateway-ca-certs"
                "name"       = "ilbgateway-ca-certs"
                "secretName" = "istio-ilbgateway-ca-certs"
              },
            ]
          }
        }
      }
    }
  }
  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = var.force_conflicts
  }
}

resource "kubernetes_manifest" "spinnaker-ingress-gateway" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "Gateway"
    "metadata" = {
      "labels" = {
        "release" = "istio"
      }
      "name"      = "gateway-spinnaker-internal"
      "namespace" = "istio-system"
    }
    "spec" = {
      "selector" = {
        "app"   = "ingressgateway-spinnaker"
        "color" = "green"
        "istio" = "ingressgateway-spinnaker-internal"
      }
      "servers" = [
        {
          "hosts" = [
            "*",
          ]
          "port" = {
            "name"     = "http"
            "number"   = 80
            "protocol" = "HTTP"
          }
          "tls" = {
            "httpsRedirect" = true
          }
        },
        {
          "hosts" = [
            "*",
          ]
          "port" = {
            "name"     = "https"
            "number"   = 443
            "protocol" = "HTTP"
          }
        },
      ]
    }
  }
  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = var.force_conflicts
  }
}

resource "kubernetes_manifest" "spinnaker-virtual-service" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "VirtualService"
    "metadata" = {
      "labels" = {
        "app" = "spinnaker"
      }
      "name"      = "spin-gate-internal"
      "namespace" = "istio-system"
    }
    "spec" = {
      "gateways" = [
        "gateway-spinnaker-internal",
      ]
      "hosts" = [
        "spinnaker.dev-usw2-dpe-1.us-west-2.dped.planfront.net",
      ]
      "http" = [
        {
          "match" = [
            {
              "uri" = {
                "regex" = "^/gate[/]?$"
              }
            },
          ]
          "rewrite" = {
            "uri" = "/"
          }
          "route" = [
            {
              "destination" = {
                "host" = "spin-gate.spinnaker.svc.cluster.local"
                "port" = {
                  "number" = 8084
                }
              }
              "weight" = 100
            },
          ]
        },
        {
          "match" = [
            {
              "uri" = {
                "prefix" = "/gate/"
              }
            },
          ]
          "rewrite" = {
            "uri" = "/"
          }
          "route" = [
            {
              "destination" = {
                "host" = "spin-gate.spinnaker.svc.cluster.local"
                "port" = {
                  "number" = 8084
                }
              }
              "weight" = 100
            },
          ]
        },
        {
          "match" = [
            {
              "uri" = {
                "prefix" = "/auth"
              }
            },
          ]
          "rewrite" = {
            "uri" = "/auth"
          }
          "route" = [
            {
              "destination" = {
                "host" = "spin-gate.spinnaker.svc.cluster.local"
                "port" = {
                  "number" = 8084
                }
              }
              "weight" = 100
            },
          ]
        },
        {
          "route" = [
            {
              "destination" = {
                "host" = "spin-deck.spinnaker.svc.cluster.local"
              }
              "weight" = 100
            },
          ]
        },
      ]
    }
  }
  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = var.force_conflicts
  }
}





locals {
  spinnaker_service_manifest = {
    "apiVersion" = "spinnaker.io/v1alpha2"
    "kind"       = "SpinnakerService"
    "metadata" = {
      "name"      = "spinnaker"
      "namespace" = "spinnaker"
    }
    "spec" = {
      "expose" = {
        # Setup NodePort services for spinnaker
        "service" = {
          "overrides" = {}
          "type"      = "NodePort"
        }
        "type" = "service"
      }
      "spinnakerConfig" = {
        "files" = {
          "${var.spinnaker_saml_settings.keyStore}"      = var.spinnaker_saml_files.keystore
          "${var.spinnaker_saml_settings.metadataLocal}" = var.spinnaker_saml_files.metadata
          "gcr_password"                                 = var.gcr_docker_registry.gcr_password
          "kubeconfig.${var.cluster_name}"               = var.local_cluster_kubeconfig
          "gcloud-pubsub-creds.json"                     = var.gcr_pubsub_settings.pubsub_creds_json_file
        }
        "config" = {
          "pubsub" = {
            "google" = {
              "enabled" = var.gcr_pubsub_settings.enabled
              "subscriptions" = [
                {
                  "ackDeadlineSeconds" = 10
                  "jsonPath"           = "gcloud-pubsub-creds.json"
                  "messageFormat"      = "GCR"
                  "name"               = "pubsub-spinnaker-plangrid"
                  "project"            = "pg-docker"
                  "subscriptionName"   = var.gcr_pubsub_settings.subscriptionName
                },
              ]
            }
          }
          "canary" = {
            "defaultJudge"          = "NetflixACAJudge-v1.0"
            "defaultMetricsAccount" = "plangrid"
            "defaultMetricsStore"   = "datadog"
            "enabled"               = "true"
            "reduxLoggerEnabled"    = "true"
            "serviceIntegrations" = [
              {
                "accounts"           = []
                "enabled"            = "false"
                "gcsEnabled"         = "false"
                "name"               = "google"
                "stackdriverEnabled" = "false"
              },
              {
                "accounts" = []
                "enabled"  = "false"
                "name"     = "prometheus"
              },
              {
                "accounts" = [
                  # no need to keep secret - these are trivially vieweable by every engineer in Datadog anyway.
                  # DD does not keep these secret in the first place.
                  {
                    "apiKey"         = var.datadog_settings.api_key
                    "applicationKey" = var.datadog_settings.application_key
                    "endpoint" = {
                      "baseUrl" = var.datadog_settings.base_url
                    }
                    "name" = var.datadog_settings.account_name
                    "supportedTypes" = [
                      "METRICS_STORE",
                    ]
                  },
                ]
                "enabled" = var.datadog_settings.enable_kayenta_metric_store
                "name"    = "datadog"
              },
              {
                "accounts" = [
                  {
                    "bucket"     = var.spinnaker_s3_buckets.kayenta_bucket
                    "name"       = "canaryaws"
                    "region"     = var.aws_region
                    "rootFolder" = "kayenta"
                    "supportedTypes" = [
                      "OBJECT_STORE",
                      "CONFIGURATION_STORE",
                    ]
                  },
                ]
                "enabled"   = "true"
                "name"      = "aws"
                "s3Enabled" = "true"
              },
            ]
            "showAllConfigsEnabled" = "true"
            "stagesEnabled"         = "true"
            "templatesEnabled"      = "true"
          }
          "metricStores" = {
            "datadog" = {
              ## DD Does not keep this secret, already committed in plaintext
              "api_key" = var.datadog_settings.api_key
              "enabled" = var.datadog_settings.enable_spinnaker_metrics
              "tags" = [
                "stacker_namespace:${var.stacker_namespace}",
                "region:${var.aws_region}",
              ]
            }
            "enabled" = "true"
            "period"  = "30"
            "prometheus" = {
              "add_source_metalabels" = "true"
              "enabled"               = "false"
            }
            "stackdriver" = {
              "enabled" = "false"
            }
          }
          "timezone" = "America/Los_Angeles"
          "persistentStorage" = {
            "persistentStoreType" = "s3"
            "s3" = {
              "bucket"     = aws_s3_bucket.spinnaker_bucket.arn
              "rootFolder" = "front50"
            }
          }
          "providers" = {
            "dockerRegistry" = {
              "accounts" = [
                {
                  "address"                 = "https://gcr.io"
                  "cacheIntervalSeconds"    = "600"
                  "email"                   = "fake.email@spinnaker.io"
                  "name"                    = "gcr"
                  "passwordFile"            = "gcr_password"
                  "requiredGroupMembership" = []
                  "username"                = "_json_key"
                  "repositories"            = []
                },
              ]
              "enabled"        = var.gcr_docker_registry.enabled
              "primaryAccount" = "gcr"
            }
            "kubernetes" = {
              "accounts" = [
                {
                  "configureImagePullSecrets" = "true"
                  "context"                   = "kubelet"
                  "customResources" = [
                    {
                      "kubernetesKind" = "VirtualService"
                    },
                    {
                      "kubernetesKind" = "DestinationRule"
                    },
                    {
                      "kubernetesKind" = "Policy"
                    },
                    {
                      "kubernetesKind" = "PeerAuthentication"
                    },
                  ]
                  "dockerRegistries" = [
                    {
                      "accountName" = "gcr"
                      "namespaces"  = []
                    },
                  ]
                  "kubeconfigFile" = "kubeconfig.${var.cluster_name}"
                  "name"           = "${var.cluster_name}-v2"
                  "namespaces" = [
                    "default",
                    "spinnaker",
                    "istio-system",
                  ]
                  "omitNamespaces"          = []
                  "providerVersion"         = "V2"
                  "requiredGroupMembership" = []
                },
              ]
              "enabled"        = "true"
              "primaryAccount" = "${var.cluster_name}-v2"
            }
          }
          "deploymentEnvironment" = {
            "size"        = "SMALL"
            "type"        = "Distributed"
            "accountName" = "${var.cluster_name}-v2"
            "customSizing" = {
              "spin-gate" = {
                "limits" = {
                  "cpu"    = 2
                  "memory" = "3000Mi"
                }
                "requests" = {
                  "cpu"    = 2
                  "memory" = "3000Mi"
                }
              }
              "spin-front50" = {
                "limits" = {
                  "cpu"    = 1
                  "memory" = "3000Mi"
                }
                "requests" = {
                  "cpu"    = 1
                  "memory" = "3000Mi"
                }
              }
              "spin-rosco" = {
                "limits" = {
                  "cpu"    = 1
                  "memory" = "1200Mi"
                }
                "requests" = {
                  "cpu"    = 1
                  "memory" = "1200Mi"
                }
              }
              "spin-deck" = {
                "limits" = {
                  "cpu"    = 1
                  "memory" = "1200Mi"
                }
                "requests" = {
                  "cpu"    = 1
                  "memory" = "1200Mi"
                }
              }
              "spin-clouddriver" = {
                "replicas" = 8
                "limits" = {
                  "cpu"    = 2
                  "memory" = "12000Mi"
                }
                "requests" = {
                  "cpu"    = 2
                  "memory" = "12000Mi"
                }
              }
              "spin-orca" = {
                "replicas" = 4
                "limits" = {
                  "cpu"    = 2
                  "memory" = "6000Mi"
                }
                "requests" = {
                  "cpu"    = 2
                  "memory" = "6000Mi"
                }
              }
              "spin-igor" = {
                "limits" = {
                  "cpu"    = 1
                  "memory" = "3000Mi"
                }
                "requests" = {
                  "cpu"    = 1
                  "memory" = "3000Mi"
                }
              }
              "spin-echo" = {
                "limits" = {
                  "cpu"    = 1
                  "memory" = "6000Mi"
                }
                "requests" = {
                  "cpu"    = 1
                  "memory" = "6000Mi"
                }
              }
            }
          }
          "security" = {
            "apiSecurity" = {
              "overrideBaseUrl" = "https://spinnaker.${var.planfront_url}/gate"
              "ssl" = {
                "enabled" = "false"
              }
            }
            "authn" = {
              "enabled" = "true"
              "saml"    = var.spinnaker_saml_settings
            }
            "authz" = {
              "enabled" = "false"
            }
            "uiSecurity" = {
              "overrideBaseUrl" = "https://spinnaker.${var.planfront_url}/gate"
              "ssl" = {
                "enabled" = "false"
              }
            }
          }
          "ci" = {
            "jenkins" = {
              "enabled" = var.jenkins_enabled
              "masters" = [
                var.jenkins_settings
              ]
            }
          }
          "version" = var.spinnaker_version
        }
        "profiles" = {
          "clouddriver" = {
            "kubernetes" = {
              "jobs" = {
                "append-suffix" = false
              }
            }
          }
          "deck" = {}
          "echo" = {
            "rest" = {
              "enabled" = var.pipelayer_settings.enable_pipelayer
              "endpoints" = [
                {
                  "wrap" = "false"
                  "url"  = var.pipelayer_settings.pipelayer_url
                }
              ]
            }
            "slack" = var.slack_settings
          }
          "fiat"    = {}
          "front50" = {}
          "gate" = {
            "saml" = {
              "maxAuthenticationAge" = "86400"
            }
          }
          "igor" = {
            "spinnaker" = {
              "pollingSafeguard" = {
                "itemUpperThreshold" = "250000"
              }
            }
          }
          "kayenta" = {
            # Set datadog metric cache to poll every 45 minutes to avoid api limit
            "datadog" = {
              "metadataCachingIntervalMS" : "2700000"
            }
            newrelic = {
              "enabled" = var.newrelic_kayenta_settings.enable_nr_kayenta
              "accounts" = [
                {
                  "name"           = var.newrelic_kayenta_settings.account_name
                  "apiKey"         = var.newrelic_kayenta_settings.api_key
                  "applicationKey" = var.newrelic_kayenta_settings.application_key
                  "supportedTypes" = [
                    "METRICS_STORE"
                  ]
                }
              ]
            }
          }
          "orca" = {
            "queue" = {
              "zombieCheck" = {
                "enabled" : "true"
              }
            }
            #            "redis" = {
            #              "clients" = {
            #                "executionRepository" = {
            #                  "primary" = {
            #                    "driver" = "redis"
            #                    "config" = {
            #                      "connection" = "changeme"
            #                    }
            #                  }
            #                }
            #              }
            #            }
            "pollers" = {
              "oldPipelineCleanup" = {
                "enabled"                   = "true"    # This enables old pipeline execution cleanup (default: false)
                "intervalMs"                = "3600000" # How many milliseconds between pipeline cleanup runs (default: 1hr or 3600000)
                "thresholdDays"             = "14"      # How old a pipeline execution must be to be deleted (default: 30)
                "minimumPipelineExecutions" = "5"       # How many executions to keep around (default: 5)
              }
            }
            "tasks" = {
              "daysOfExecutionHistory" = "25" # How many days to keep old task executions around
            }
          }
        }
        "service-settings" = {
          "clouddriver" = {
            "env" = {
              "JAVA_OPTS" = "-Xms9600M -Xmx10200M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-clouddriver"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "deck" = {
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-deck"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "echo" = {
            "env" = {
              "JAVA_OPTS" = "-Xms4800M -Xmx5100M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-echo"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "fiat" = {
            "env" = {
              "JAVA_OPTS" = "-Xms2400M -Xmx2550M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-fiat"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "front50" = {
            "env" = {
              "JAVA_OPTS" = "-Xms2400M -Xmx2550M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-front50"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "gate" = {
            "env" = {
              "JAVA_OPTS" = "-Xms2400M -Xmx2550M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-gate"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "igor" = {
            "env" = {
              "JAVA_OPTS" = "-Xms2400M -Xmx2550M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-igor"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "kayenta" = {
            "env" = {
              "JAVA_OPTS" = "-Xms960M -Xmx1020M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-kayenta"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "orca" = {
            "env" = {
              "JAVA_OPTS" = "-Xms4800M -Xmx5100M"
            }
            "kubernetes" = {
              "podAnnotations" = {
                "pg_app"                 = "spin-orca"
                "iam.amazonaws.com/role" = aws_iam_role.spinnaker-role.arn
              }
            }
          }
          "redis" = {
            "enabled" = "true"
          }
          "rosco" = {
            "enabled" = "false"
          }
        }
      }
    }
  }
}


resource "null_resource" "spinnaker-service-manifest-apply" {
  triggers = {
    template = "${yamlencode(local.spinnaker_service_manifest)}"
  }

  # Ensure Kubeconfig is set to the correct cluster
  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
  }

  # Apply the CRD manifest
  provisioner "local-exec" {
    command = "echo '${yamlencode(local.spinnaker_service_manifest)}' | kubectl apply -f -"
  }

}


