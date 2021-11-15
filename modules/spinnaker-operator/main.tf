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
  manifest = file("${path.module}/files/spinnaker-operator-clusterrole.yaml")
}

resource "kubernetes_manifest" "spinnaker-operator-crd-update-role" {
  manifest = templatefile("${path.module}/files/spinnaker-operator-crd-update-role.yaml.tpl", {
      kubernetes_namespace = kubernetes_namespace.spinnaker-operator-namespace.metadata.0.name
    })
}

resource "kubernetes_manifest" "spinnakerservices-crd" {
  manifest = file("${path.module}/files/spinnakerservices-crd.yaml")
}

resource "kubernetes_manifest" "spinnakeraccounts-crd" {
  manifest = file("${path.module}/files/spinnakeraccounts-crd.yaml")
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
