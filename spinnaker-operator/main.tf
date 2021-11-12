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

resource "kubernetes_namespace" "spinnaker-operator-namespace" {
  metadata {
    name = "spinnaker-operator"
  }
}

resource "kubernetes_manifest" "spinnaker-operator-clusterrole-binding" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "name" = "spinnaker-operator-binding"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "spinnaker-operator-role"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "spinnaker-operator"
        "namespace" = "spinnaker-operator"
      },
    ]
  }
}

resource "kubernetes_manifest" "spinnaker-operator-service-account" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "spinnaker-operator"
      "namespace" = kubernetes_namespace.spinnaker-operator-namespace.metadata.0.name
    }
  }
}

resource "kubernetes_manifest" "spinnaker-operator-clusterrole" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "name" = "spinnaker-operator-role"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods",
          "ingresses/status",
          "endpoints",
        ]
        "verbs" = [
          "get",
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "services",
          "events",
          "configmaps",
          "secrets",
          "namespaces",
          "ingresses",
        ]
        "verbs" = [
          "create",
          "get",
          "list",
          "update",
          "watch",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "apps",
          "extensions",
        ]
        "resources" = [
          "deployments",
          "daemonsets",
          "replicasets",
          "statefulsets",
        ]
        "verbs" = [
          "create",
          "get",
          "list",
          "update",
          "watch",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "monitoring.coreos.com",
        ]
        "resources" = [
          "servicemonitors",
        ]
        "verbs" = [
          "get",
          "create",
        ]
      },
      {
        "apiGroups" = [
          "spinnaker.io",
        ]
        "resources" = [
          "*",
          "spinnakerservices",
        ]
        "verbs" = [
          "create",
          "get",
          "list",
          "update",
          "watch",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "admissionregistration.k8s.io",
        ]
        "resources" = [
          "validatingwebhookconfigurations",
        ]
        "verbs" = [
          "*",
        ]
      },
      {
        "apiGroups" = [
          "networking.k8s.io",
          "extensions",
        ]
        "resources" = [
          "ingresses",
        ]
        "verbs" = [
          "get",
          "list",
          "watch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "spinnaker-operator-crd-update-role" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "Role"
    "metadata" = {
      "name"      = "spinnaker-operator"
      "namespace" = kubernetes_namespace.spinnaker-operator-namespace.metadata.0.name
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods",
          "services",
          "endpoints",
          "persistentvolumeclaims",
          "events",
          "configmaps",
          "secrets",
          "namespaces",
        ]
        "verbs" = [
          "*",
        ]
      },
      {
        "apiGroups" = [
          "batch",
          "extensions",
        ]
        "resources" = [
          "jobs",
        ]
        "verbs" = [
          "*",
        ]
      },
      {
        "apiGroups" = [
          "apps",
          "extensions",
        ]
        "resources" = [
          "deployments",
          "daemonsets",
          "replicasets",
          "statefulsets",
        ]
        "verbs" = [
          "*",
        ]
      },
      {
        "apiGroups" = [
          "monitoring.coreos.com",
        ]
        "resources" = [
          "servicemonitors",
        ]
        "verbs" = [
          "get",
          "create",
        ]
      },
      {
        "apiGroups" = [
          "apps",
        ]
        "resourceNames" = [
          "spinnaker-operator",
        ]
        "resources" = [
          "deployments/finalizers",
        ]
        "verbs" = [
          "update",
        ]
      },
      {
        "apiGroups" = [
          "spinnaker.io",
        ]
        "resources" = [
          "*",
          "spinnakerservices",
        ]
        "verbs" = [
          "*",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "spinnakerservices-crd" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1beta1"
    "kind"       = "CustomResourceDefinition"
    "metadata" = {
      "name" = "spinnakerservices.spinnaker.io"
    }
    "spec" = {
      "additionalPrinterColumns" = [
        {
          "JSONPath"    = ".status.version"
          "description" = "Version"
          "name"        = "version"
          "type"        = "string"
        },
        {
          "JSONPath"    = ".status.lastDeployed.config.lastUpdatedAt"
          "description" = "Last Configured"
          "name"        = "lastConfigured"
          "type"        = "date"
        },
        {
          "JSONPath"    = ".status.status"
          "description" = "Status"
          "name"        = "status"
          "type"        = "string"
        },
        {
          "JSONPath"    = ".status.serviceCount"
          "description" = "Services"
          "name"        = "services"
          "type"        = "number"
        },
        {
          "JSONPath"    = ".status.uiUrl"
          "description" = "URL"
          "name"        = "url"
          "type"        = "string"
        },
        {
          "JSONPath"    = ".status.apiUrl"
          "description" = "API URL"
          "name"        = "apiUrl"
          "priority"    = 1
          "type"        = "string"
        },
      ]
      "group" = "spinnaker.io"
      "names" = {
        "kind"     = "SpinnakerService"
        "listKind" = "SpinnakerServiceList"
        "plural"   = "spinnakerservices"
        "shortNames" = [
          "spinsvc",
        ]
        "singular" = "spinnakerservice"
      }
      "scope" = "Namespaced"
      "subresources" = {
        "status" = {}
      }
      "validation" = {
        "openAPIV3Schema" = {
          "description" = "SpinnakerService is the Schema for the spinnakerservices API"
          "properties" = {
            "apiVersion" = {
              "description" = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources"
              "type"        = "string"
            }
            "kind" = {
              "description" = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds"
              "type"        = "string"
            }
            "metadata" = {
              "type" = "object"
            }
            "spec" = {
              "description" = "SpinnakerServiceSpec defines the desired state of SpinnakerService"
              "properties" = {
                "accounts" = {
                  "properties" = {
                    "dynamic" = {
                      "description" = "Enable accounts to be added dynamically"
                      "type"        = "boolean"
                    }
                    "enabled" = {
                      "description" = "Enable the injection of SpinnakerAccount"
                      "type"        = "boolean"
                    }
                  }
                  "type" = "object"
                }
                "expose" = {
                  "description" = "ExposeConfig represents the configuration for exposing Spinnaker"
                  "properties" = {
                    "service" = {
                      "description" = "ExposeConfigService represents the configuration for exposing Spinnaker using k8s services"
                      "properties" = {
                        "annotations" = {
                          "additionalProperties" = {
                            "type" = "string"
                          }
                          "type" = "object"
                        }
                        "overrides" = {
                          "additionalProperties" = {
                            "description" = "ExposeConfigServiceOverrides represents expose configurations of type service, overriden by specific services"
                            "properties" = {
                              "annotations" = {
                                "additionalProperties" = {
                                  "type" = "string"
                                }
                                "type" = "object"
                              }
                              "publicPort" = {
                                "format" = "int32"
                                "type"   = "integer"
                              }
                              "type" = {
                                "type" = "string"
                              }
                            }
                            "type" = "object"
                          }
                          "type" = "object"
                        }
                        "publicPort" = {
                          "format" = "int32"
                          "type"   = "integer"
                        }
                        "type" = {
                          "type" = "string"
                        }
                      }
                      "type" = "object"
                    }
                    "type" = {
                      "type" = "string"
                    }
                  }
                  "type" = "object"
                }
                "kustomize" = {
                  "additionalProperties" = {
                    "properties" = {
                      "deployment" = {
                        "properties" = {
                          "patches" = {
                            "description" = "Patches is a list of patches, where each one can be either a Strategic Merge Patch or a JSON patch. Each patch can be applied to multiple target objects."
                            "items" = {
                              "type" = "string"
                            }
                            "type" = "array"
                          }
                          "patchesJson6902" = {
                            "description" = "JSONPatches is a list of JSONPatch for applying JSON patch. Format documented at https://tools.ietf.org/html/rfc6902 and http://jsonpatch.com"
                            "type"        = "string"
                          }
                          "patchesStrategicMerge" = {
                            "description" = "PatchesStrategicMerge specifies the relative path to a file containing a strategic merge patch.  Format documented at https://github.com/kubernetes/community/blob/master/contributors/devel/strategic-merge-patch.md URLs and globs are not supported."
                            "items" = {
                              "description" = "PatchStrategicMerge represents a relative path to a strategic merge patch with the format https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/strategic-merge-patch.md"
                              "type"        = "string"
                            }
                            "type" = "array"
                          }
                        }
                        "type" = "object"
                      }
                      "service" = {
                        "properties" = {
                          "patches" = {
                            "description" = "Patches is a list of patches, where each one can be either a Strategic Merge Patch or a JSON patch. Each patch can be applied to multiple target objects."
                            "items" = {
                              "type" = "string"
                            }
                            "type" = "array"
                          }
                          "patchesJson6902" = {
                            "description" = "JSONPatches is a list of JSONPatch for applying JSON patch. Format documented at https://tools.ietf.org/html/rfc6902 and http://jsonpatch.com"
                            "type"        = "string"
                          }
                          "patchesStrategicMerge" = {
                            "description" = "PatchesStrategicMerge specifies the relative path to a file containing a strategic merge patch.  Format documented at https://github.com/kubernetes/community/blob/master/contributors/devel/strategic-merge-patch.md URLs and globs are not supported."
                            "items" = {
                              "description" = "PatchStrategicMerge represents a relative path to a strategic merge patch with the format https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/strategic-merge-patch.md"
                              "type"        = "string"
                            }
                            "type" = "array"
                          }
                        }
                        "type" = "object"
                      }
                    }
                    "type" = "object"
                  }
                  "description" = "Patch Kustomization of service and deployment per service"
                  "type"        = "object"
                }
                "spinnakerConfig" = {
                  "properties" = {
                    "config" = {
                      "description" = "Main deployment configuration to be passed to Halyard"
                    }
                    "files" = {
                      "additionalProperties" = {
                        "type" = "string"
                      }
                      "description" = "Supporting files for the Spinnaker config"
                      "type"        = "object"
                    }
                    "profiles" = {
                      "additionalProperties" = {}
                      "description"          = "Service profiles will be parsed as YAML"
                      "type"                 = "object"
                    }
                    "service-settings" = {
                      "additionalProperties" = {}
                      "description"          = "Parsed service settings - comments are stripped"
                      "type"                 = "object"
                    }
                  }
                  "type" = "object"
                }
                "validation" = {
                  "description" = "validation settings for the deployment"
                  "properties" = {
                    "canary" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "ci" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "failFast" = {
                      "description" = "Fail validation on the first failed validation, defaults to false"
                      "type"        = "boolean"
                    }
                    "failOnError" = {
                      "description" = "Report errors but do not fail validation, defaults to true"
                      "type"        = "boolean"
                    }
                    "frequencySeconds" = {
                      "type"        = "string"
                      "description" = "Number of seconds between each validation"
                    }
                    "metricStores" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "notifications" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "persistentStorage" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "providers" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                    "pubsub" = {
                      "additionalProperties" = {
                        "properties" = {
                          "enabled" = {
                            "description" = "Enable or disable validation, defaults to false"
                            "type"        = "boolean"
                          }
                          "failOnError" = {
                            "description" = "Report errors but do not fail validation, defaults to true"
                            "type"        = "boolean"
                          }
                          "frequencySeconds" = {
                            "type"        = "string"
                            "description" = "Number of seconds between each validation"
                          }
                        }
                        "required" = [
                          "enabled",
                        ]
                        "type" = "object"
                      }
                      "type" = "object"
                    }
                  }
                  "type" = "object"
                }
              }
              "required" = [
                "spinnakerConfig",
              ]
              "type" = "object"
            }
            "status" = {
              "description" = "SpinnakerServiceStatus defines the observed state of SpinnakerService"
              "properties" = {
                "accountCount" = {
                  "description" = "Number of accounts"
                  "type"        = "integer"
                }
                "apiUrl" = {
                  "description" = "Exposed Gate URL"
                  "type"        = "string"
                }
                "lastDeployed" = {
                  "additionalProperties" = {
                    "properties" = {
                      "hash" = {
                        "type" = "string"
                      }
                      "lastUpdatedAt" = {
                        "format" = "date-time"
                        "type"   = "string"
                      }
                    }
                    "required" = [
                      "hash",
                    ]
                    "type" = "object"
                  }
                  "description" = "Last deployed hashes"
                  "type"        = "object"
                }
                "serviceCount" = {
                  "description" = "Number of services in Spinnaker"
                  "type"        = "integer"
                }
                "services" = {
                  "description" = "Services deployment information"
                  "items" = {
                    "description" = "SpinnakerDeploymentStatus represents the deployment status of a single service"
                    "properties" = {
                      "image" = {
                        "description" = "Image deployed"
                        "type"        = "string"
                      }
                      "name" = {
                        "description" = "Name of the service deployed"
                        "type"        = "string"
                      }
                      "readyReplicas" = {
                        "description" = "Total number of ready pods targeted by this deployment."
                        "format"      = "int32"
                        "type"        = "integer"
                      }
                      "replicas" = {
                        "description" = "Total number of non-terminated pods targeted by this deployment (their labels match the selector)."
                        "format"      = "int32"
                        "type"        = "integer"
                      }
                    }
                    "required" = [
                      "name",
                    ]
                    "type" = "object"
                  }
                  "type" = "array"
                }
                "status" = {
                  "description" = "Overall Spinnaker status"
                  "type"        = "string"
                }
                "uiUrl" = {
                  "description" = "Exposed Deck URL"
                  "type"        = "string"
                }
                "version" = {
                  "description" = "Current deployed version of Spinnaker"
                  "type"        = "string"
                }
              }
              "type" = "object"
            }
          }
          "type" = "object"
        }
      }
      "version" = "v1alpha2"
      "versions" = [
        {
          "name"    = "v1alpha2"
          "served"  = true
          "storage" = true
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "spinnakeraccounts-crd" {
  manifest = {
    "apiVersion" = "apiextensions.k8s.io/v1beta1"
    "kind"       = "CustomResourceDefinition"
    "metadata" = {
      "name" = "spinnakeraccounts.spinnaker.io"
    }
    "spec" = {
      "additionalPrinterColumns" = [
        {
          "JSONPath"    = ".spec.type"
          "description" = "Type"
          "name"        = "type"
          "type"        = "string"
        },
        {
          "JSONPath"    = ".status.LastValidatedAt"
          "description" = "Last Validated"
          "name"        = "lastValidated"
          "type"        = "date"
        },
        {
          "JSONPath"    = ".status.InvalidReason"
          "description" = "Invalid Reason"
          "name"        = "reason"
          "type"        = "string"
        },
      ]
      "group" = "spinnaker.io"
      "names" = {
        "kind"     = "SpinnakerAccount"
        "listKind" = "SpinnakerAccountList"
        "plural"   = "spinnakeraccounts"
        "shortNames" = [
          "spinaccount",
        ]
        "singular" = "spinnakeraccount"
      }
      "scope" = "Namespaced"
      "subresources" = {
        "status" = {}
      }
      "validation" = {
        "openAPIV3Schema" = {
          "description" = "SpinnakerAccount is the Schema for the spinnakeraccounts API"
          "properties" = {
            "apiVersion" = {
              "description" = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources"
              "type"        = "string"
            }
            "kind" = {
              "description" = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds"
              "type"        = "string"
            }
            "metadata" = {
              "type" = "object"
            }
            "spec" = {
              "description" = "SpinnakerAccountSpec defines the desired state of SpinnakerAccount"
              "properties" = {
                "enabled" = {
                  "type" = "boolean"
                }
                "kubernetes" = {
                  "properties" = {
                    "kubeconfig" = {
                      "description" = "Kubeconfig config referenced directly"
                      "properties" = {
                        "apiVersion" = {
                          "description" = "Legacy field from pkg/api/types.go TypeMeta. TODO(jlowdermilk): remove this after eliminating downstream dependencies."
                          "type"        = "string"
                        }
                        "clusters" = {
                          "description" = "Clusters is a map of referencable names to cluster configs"
                          "items" = {
                            "description" = "NamedCluster relates nicknames to cluster information"
                            "properties" = {
                              "cluster" = {
                                "description" = "Cluster holds the cluster information"
                                "properties" = {
                                  "certificate-authority" = {
                                    "description" = "CertificateAuthority is the path to a cert file for the certificate authority."
                                    "type"        = "string"
                                  }
                                  "certificate-authority-data" = {
                                    "description" = "CertificateAuthorityData contains PEM-encoded certificate authority certificates. Overrides CertificateAuthority"
                                    "format"      = "byte"
                                    "type"        = "string"
                                  }
                                  "extensions" = {
                                    "description" = "Extensions holds additional information. This is useful for extenders so that reads and writes don't clobber unknown fields"
                                    "items" = {
                                      "description" = "NamedExtension relates nicknames to extension information"
                                      "properties" = {
                                        "extension" = {
                                          "description" = "Extension holds the extension information"
                                          "type"        = "object"
                                        }
                                        "name" = {
                                          "description" = "Name is the nickname for this Extension"
                                          "type"        = "string"
                                        }
                                      }
                                      "required" = [
                                        "extension",
                                        "name",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "insecure-skip-tls-verify" = {
                                    "description" = "InsecureSkipTLSVerify skips the validity check for the server's certificate. This will make your HTTPS connections insecure."
                                    "type"        = "boolean"
                                  }
                                  "server" = {
                                    "description" = "Server is the address of the kubernetes cluster (https://hostname:port)."
                                    "type"        = "string"
                                  }
                                }
                                "required" = [
                                  "server",
                                ]
                                "type" = "object"
                              }
                              "name" = {
                                "description" = "Name is the nickname for this Cluster"
                                "type"        = "string"
                              }
                            }
                            "required" = [
                              "cluster",
                              "name",
                            ]
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                        "contexts" = {
                          "description" = "Contexts is a map of referencable names to context configs"
                          "items" = {
                            "description" = "NamedContext relates nicknames to context information"
                            "properties" = {
                              "context" = {
                                "description" = "Context holds the context information"
                                "properties" = {
                                  "cluster" = {
                                    "description" = "Cluster is the name of the cluster for this context"
                                    "type"        = "string"
                                  }
                                  "extensions" = {
                                    "description" = "Extensions holds additional information. This is useful for extenders so that reads and writes don't clobber unknown fields"
                                    "items" = {
                                      "description" = "NamedExtension relates nicknames to extension information"
                                      "properties" = {
                                        "extension" = {
                                          "description" = "Extension holds the extension information"
                                          "type"        = "object"
                                        }
                                        "name" = {
                                          "description" = "Name is the nickname for this Extension"
                                          "type"        = "string"
                                        }
                                      }
                                      "required" = [
                                        "extension",
                                        "name",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "namespace" = {
                                    "description" = "Namespace is the default namespace to use on unspecified requests"
                                    "type"        = "string"
                                  }
                                  "user" = {
                                    "description" = "AuthInfo is the name of the authInfo for this context"
                                    "type"        = "string"
                                  }
                                }
                                "required" = [
                                  "cluster",
                                  "user",
                                ]
                                "type" = "object"
                              }
                              "name" = {
                                "description" = "Name is the nickname for this Context"
                                "type"        = "string"
                              }
                            }
                            "required" = [
                              "context",
                              "name",
                            ]
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                        "current-context" = {
                          "description" = "CurrentContext is the name of the context that you would like to use by default"
                          "type"        = "string"
                        }
                        "extensions" = {
                          "description" = "Extensions holds additional information. This is useful for extenders so that reads and writes don't clobber unknown fields"
                          "items" = {
                            "description" = "NamedExtension relates nicknames to extension information"
                            "properties" = {
                              "extension" = {
                                "description" = "Extension holds the extension information"
                                "type"        = "object"
                              }
                              "name" = {
                                "description" = "Name is the nickname for this Extension"
                                "type"        = "string"
                              }
                            }
                            "required" = [
                              "extension",
                              "name",
                            ]
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                        "kind" = {
                          "description" = "Legacy field from pkg/api/types.go TypeMeta. TODO(jlowdermilk): remove this after eliminating downstream dependencies."
                          "type"        = "string"
                        }
                        "preferences" = {
                          "description" = "Preferences holds general information to be use for cli interactions"
                          "properties" = {
                            "colors" = {
                              "type" = "boolean"
                            }
                            "extensions" = {
                              "description" = "Extensions holds additional information. This is useful for extenders so that reads and writes don't clobber unknown fields"
                              "items" = {
                                "description" = "NamedExtension relates nicknames to extension information"
                                "properties" = {
                                  "extension" = {
                                    "description" = "Extension holds the extension information"
                                    "type"        = "object"
                                  }
                                  "name" = {
                                    "description" = "Name is the nickname for this Extension"
                                    "type"        = "string"
                                  }
                                }
                                "required" = [
                                  "extension",
                                  "name",
                                ]
                                "type" = "object"
                              }
                              "type" = "array"
                            }
                          }
                          "type" = "object"
                        }
                        "users" = {
                          "description" = "AuthInfos is a map of referencable names to user configs"
                          "items" = {
                            "description" = "NamedAuthInfo relates nicknames to auth information"
                            "properties" = {
                              "name" = {
                                "description" = "Name is the nickname for this AuthInfo"
                                "type"        = "string"
                              }
                              "user" = {
                                "description" = "AuthInfo holds the auth information"
                                "properties" = {
                                  "as" = {
                                    "description" = "Impersonate is the username to imperonate.  The name matches the flag."
                                    "type"        = "string"
                                  }
                                  "as-groups" = {
                                    "description" = "ImpersonateGroups is the groups to imperonate."
                                    "items" = {
                                      "type" = "string"
                                    }
                                    "type" = "array"
                                  }
                                  "as-user-extra" = {
                                    "additionalProperties" = {
                                      "items" = {
                                        "type" = "string"
                                      }
                                      "type" = "array"
                                    }
                                    "description" = "ImpersonateUserExtra contains additional information for impersonated user."
                                    "type"        = "object"
                                  }
                                  "auth-provider" = {
                                    "description" = "AuthProvider specifies a custom authentication plugin for the kubernetes cluster."
                                    "properties" = {
                                      "config" = {
                                        "additionalProperties" = {
                                          "type" = "string"
                                        }
                                        "type" = "object"
                                      }
                                      "name" = {
                                        "type" = "string"
                                      }
                                    }
                                    "required" = [
                                      "config",
                                      "name",
                                    ]
                                    "type" = "object"
                                  }
                                  "client-certificate" = {
                                    "description" = "ClientCertificate is the path to a client cert file for TLS."
                                    "type"        = "string"
                                  }
                                  "client-certificate-data" = {
                                    "description" = "ClientCertificateData contains PEM-encoded data from a client cert file for TLS. Overrides ClientCertificate"
                                    "format"      = "byte"
                                    "type"        = "string"
                                  }
                                  "client-key" = {
                                    "description" = "ClientKey is the path to a client key file for TLS."
                                    "type"        = "string"
                                  }
                                  "client-key-data" = {
                                    "description" = "ClientKeyData contains PEM-encoded data from a client key file for TLS. Overrides ClientKey"
                                    "format"      = "byte"
                                    "type"        = "string"
                                  }
                                  "exec" = {
                                    "description" = "Exec specifies a custom exec-based authentication plugin for the kubernetes cluster."
                                    "properties" = {
                                      "apiVersion" = {
                                        "description" = "Preferred input version of the ExecInfo. The returned ExecCredentials MUST use the same encoding version as the input."
                                        "type"        = "string"
                                      }
                                      "args" = {
                                        "description" = "Arguments to pass to the command when executing it."
                                        "items" = {
                                          "type" = "string"
                                        }
                                        "type" = "array"
                                      }
                                      "command" = {
                                        "description" = "Command to execute."
                                        "type"        = "string"
                                      }
                                      "env" = {
                                        "description" = "Env defines additional environment variables to expose to the process. These are unioned with the host's environment, as well as variables client-go uses to pass argument to the plugin."
                                        "items" = {
                                          "description" = "ExecEnvVar is used for setting environment variables when executing an exec-based credential plugin."
                                          "properties" = {
                                            "name" = {
                                              "type" = "string"
                                            }
                                            "value" = {
                                              "type" = "string"
                                            }
                                          }
                                          "required" = [
                                            "name",
                                            "value",
                                          ]
                                          "type" = "object"
                                        }
                                        "type" = "array"
                                      }
                                    }
                                    "required" = [
                                      "command",
                                    ]
                                    "type" = "object"
                                  }
                                  "extensions" = {
                                    "description" = "Extensions holds additional information. This is useful for extenders so that reads and writes don't clobber unknown fields"
                                    "items" = {
                                      "description" = "NamedExtension relates nicknames to extension information"
                                      "properties" = {
                                        "extension" = {
                                          "description" = "Extension holds the extension information"
                                          "type"        = "object"
                                        }
                                        "name" = {
                                          "description" = "Name is the nickname for this Extension"
                                          "type"        = "string"
                                        }
                                      }
                                      "required" = [
                                        "extension",
                                        "name",
                                      ]
                                      "type" = "object"
                                    }
                                    "type" = "array"
                                  }
                                  "password" = {
                                    "description" = "Password is the password for basic authentication to the kubernetes cluster."
                                    "type"        = "string"
                                  }
                                  "token" = {
                                    "description" = "Token is the bearer token for authentication to the kubernetes cluster."
                                    "type"        = "string"
                                  }
                                  "tokenFile" = {
                                    "description" = "TokenFile is a pointer to a file that contains a bearer token (as described above).  If both Token and TokenFile are present, Token takes precedence."
                                    "type"        = "string"
                                  }
                                  "username" = {
                                    "description" = "Username is the username for basic authentication to the kubernetes cluster."
                                    "type"        = "string"
                                  }
                                }
                                "type" = "object"
                              }
                            }
                            "required" = [
                              "name",
                              "user",
                            ]
                            "type" = "object"
                          }
                          "type" = "array"
                        }
                      }
                      "required" = [
                        "clusters",
                        "contexts",
                        "current-context",
                        "preferences",
                        "users",
                      ]
                      "type" = "object"
                    }
                    "kubeconfigFile" = {
                      "description" = "KubeconfigFile referenced as an encrypted secret"
                      "type"        = "string"
                    }
                    "kubeconfigSecret" = {
                      "description" = "Kubeconfig referenced as a Kubernetes secret"
                      "properties" = {
                        "key" = {
                          "type" = "string"
                        }
                        "name" = {
                          "type" = "string"
                        }
                      }
                      "required" = [
                        "key",
                        "name",
                      ]
                      "type" = "object"
                    }
                    "useServiceAccount" = {
                      "description" = "UseServiceAccount authenticate to the target cluster using the service account mounted in Spinnaker's pods"
                      "type"        = "boolean"
                    }
                  }
                  "type" = "object"
                }
                "permissions" = {
                  "additionalProperties" = {
                    "items" = {
                      "type" = "string"
                    }
                    "type" = "array"
                  }
                  "type" = "object"
                }
                "settings" = {}
                "type" = {
                  "type" = "string"
                }
                "validation" = {
                  "properties" = {
                    "enabled" = {
                      "description" = "Enable or disable validation, defaults to false"
                      "type"        = "boolean"
                    }
                    "failOnError" = {
                      "description" = "Report errors but do not fail validation, defaults to true"
                      "type"        = "boolean"
                    }
                    "frequencySeconds" = {
                      "type"        = "string"
                      "description" = "Number of seconds between each validation"
                    }
                  }
                  "required" = [
                    "enabled",
                  ]
                  "type" = "object"
                }
              }
              "required" = [
                "enabled",
                "type",
              ]
              "type" = "object"
            }
            "status" = {
              "description" = "SpinnakerAccountStatus defines the observed state of SpinnakerAccount"
              "properties" = {
                "invalidReason" = {
                  "type" = "string"
                }
                "lastValidatedAt" = {
                  "description" = "Timestamp is a struct that is equivalent to Time, but intended for protobuf marshalling/unmarshalling. It is generated into a serialization that matches Time. Do not use in Go structs."
                  "properties" = {
                    "nanos" = {
                      "description" = "Non-negative fractions of a second at nanosecond resolution. Negative second values with fractions must still have non-negative nanos values that count forward in time. Must be from 0 to 999,999,999 inclusive. This field may be limited in precision depending on context."
                      "format"      = "int32"
                      "type"        = "integer"
                    }
                    "seconds" = {
                      "description" = "Represents seconds of UTC time since Unix epoch 1970-01-01T00:00:00Z. Must be from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59Z inclusive."
                      "format"      = "int64"
                      "type"        = "integer"
                    }
                  }
                  "required" = [
                    "nanos",
                    "seconds",
                  ]
                  "type" = "object"
                }
              }
              "required" = [
                "invalidReason",
                "lastValidatedAt",
              ]
              "type" = "object"
            }
          }
          "type" = "object"
        }
      }
      "version" = "v1alpha2"
      "versions" = [
        {
          "name"    = "v1alpha2"
          "served"  = true
          "storage" = true
        },
      ]
    }
  }
}

resource "kubernetes_deployment" "spinnaker-operator-deployment" {
  metadata {
    name      = "spinnaker-operator"
    namespace = kubernetes_namespace.spinnaker-operator-namespace.metadata.0.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "name" = "spinnaker-operator"
      }
    }
    template {
      metadata {
        labels = {
          "name" = "spinnaker-operator"
        }
      }
      spec {
        service_account_name = "spinnaker-operator"
        container {
          name              = "spinnaker-operator"
          image             = "armory/spinnaker-operator:1.2.5"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 9876
            name           = "http"
            protocol       = "TCP"
          }
          command = [
            "spinnaker-operator",
          ]
          env {
            name  = "OPERATOR_NAME"
            value = "spinnaker-operator"
          }
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
        }
        container {
          name              = "halyard"
          image             = "armory/halyard:operator-ccae06e"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 8064
            name           = "http"
            protocol       = "TCP"
          }
          liveness_probe {
            initial_delay_seconds = 30
            period_seconds        = 20
            tcp_socket {
              port = "8064"
            }
          }
          readiness_probe {
            failure_threshold = 20
            http_get {
              path = "/health"
              port = "8064"
            }
            initial_delay_seconds = 20
            period_seconds        = 5
          }
        }
      }
    }
  }
}