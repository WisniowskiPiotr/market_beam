

locals {
    pulsar_release_name = "pulsar-release"
    pulsar_admins = toset(["proxy-admin","broker-admin","admin"])
    pulsar_key_file_name = "jwtRS256.key"
    pulsar_pub_key_file_name = "jwtRS256.key.pub"
}


resource "kubernetes_namespace" "pulsar_namespace" {
  depends_on = [ terraform_data.minikube_cluster ]
  metadata {
    name = "pulsar-namespace"
  }
  wait_for_default_service_account = true
}


resource "terraform_data" "pulsar_main_key" {
  input = [
    local.pulsar_key_file_name,
    local.pulsar_pub_key_file_name
  ]
  provisioner "local-exec" {
    command = "ssh-keygen -t rsa -b 4096 -m PEM -N \"\" -f ${local.pulsar_key_file_name} && openssl rsa -in ${local.pulsar_key_file_name} -pubout -outform PEM -out ${local.pulsar_pub_key_file_name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ${self.output[0]}; rm ${self.output[1]}"
  }
}


resource "kubernetes_secret" "pulsar_main_key" {
  metadata {
    name      = "${local.pulsar_release_name}-token-asymmetric-key"
    namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
  }

  data = {
    PRIVATEKEY = filebase64(terraform_data.pulsar_main_key.output[0])
    PUBLICKEY  = filebase64(terraform_data.pulsar_main_key.output[1])
  }

  type = "Opaque"
}


resource "terraform_data" "pulsar_admin_key" {
  for_each = local.pulsar_admins
  input = [
    terraform_data.pulsar_main_key.output[0],
    "${each.key}.${terraform_data.pulsar_main_key.output[0]}"
  ]
  provisioner "local-exec" {
    command = <<EOT
      HEADER={\"alg\":\"RS256\",\"typ\":\"JWT\"}
      PAYLOAD={\"sub\":\"${each.key}\"}
      HEADER_BASE64=$(echo $HEADER | openssl base64 -e | tr -d '\n' | tr '+/' '-_' | tr -d '=')
      PAYLOAD_BASE64=$(echo $PAYLOAD | openssl base64 -e | tr -d '\n' | tr '+/' '-_' | tr -d '=')
      SIGNATURE=$(echo -n "$HEADER_BASE64.$PAYLOAD_BASE64" | openssl dgst -sha256 -sign ${terraform_data.pulsar_main_key.output[0]} | openssl base64 -e | tr -d '\n' | tr '+/' '-_' | tr -d '=')
      echo "$HEADER_BASE64.$PAYLOAD_BASE64.$SIGNATURE" >> ${each.key}.${terraform_data.pulsar_main_key.output[0]}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ${each.key}.${self.output[0]}"
  }
}

resource "kubernetes_secret" "pulsar_admin_keys" {
  for_each = local.pulsar_admins
  metadata {
    name      = "${local.pulsar_release_name}-token-${each.key}"
    namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
  }
  data = {
    TOKEN = filebase64(terraform_data.pulsar_admin_key[each.key].output[1])
    TYPE  = base64encode("asymmetric")
  }
  type = "Opaque"
}

# resource "kubernetes_persistent_volume" "pulsar_persistent_volume" {
#   for_each = local.pulsar_data_volumes
#   depends_on = [ terraform_data.minikube_cluster ]
#   metadata {
#     name = replace(each.key,"_", "-")
#   }

#   spec {
#     capacity = {
#       storage = "2Gi"
#     }

#     access_modes = ["ReadWriteOnce"]

#     persistent_volume_source {
#       host_path {
#         path = "${local.minikube_data_path}/${each.key}" 
#       }
#     }
#   }
# }


resource "helm_release" "pulsar" {
  repository       = "https://pulsar.apache.org/charts"
  chart            = "pulsar"
  version          = "3.6.0"
  name             = local.pulsar_release_name
  namespace        = kubernetes_namespace.pulsar_namespace.metadata[0].name
  values           = [file("pulsar_chart_values.yaml")]
  lint = true
  timeout          = 20 * 60
  #depends_on = [kubernetes_persistent_volume.pulsar_persistent_volume]
  depends_on = [terraform_data.minikube_cluster]
}


# helm status -n pulsar-namespace pulsar-release
# NAME: pulsar-release
# LAST DEPLOYED: Sun Dec 29 20:58:42 2024
# NAMESPACE: pulsar-namespace
# STATUS: failed
# REVISION: 1
# NOTES:
# 1. Get your 'admin' user password by running:

#    kubectl get secret --namespace pulsar-namespace pulsar-release-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


# 2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:

#    pulsar-release-grafana.pulsar-namespace.svc.cluster.local

#    Get the Grafana URL to visit by running these commands in the same shell:
#      export POD_NAME=$(kubectl get pods --namespace pulsar-namespace -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=pulsar-release" -o jsonpath="{.items[0].metadata.name}")
#      kubectl --namespace pulsar-namespace port-forward $POD_NAME 3000

# 3. Login with the password from step 1 and the username: admin
# #################################################################################
# ######   WARNING: Persistence is disabled!!! You will lose your data when   #####
# ######            the Grafana pod is terminated.                            #####
# #################################################################################

# kube-state-metrics is a simple service that listens to the Kubernetes API server and generates metrics about the state of the objects.
# The exposed metrics can be found here:
# https://github.com/kubernetes/kube-state-metrics/blob/master/docs/README.md#exposed-metrics

# The metrics are exported on the HTTP endpoint /metrics on the listening port.
# In your case, pulsar-release-kube-state-metrics.pulsar-namespace.svc.cluster.local:8080/metrics

# They are served either as plaintext or protobuf depending on the Accept header.
# They are designed to be consumed either by Prometheus itself or by a scraper that is compatible with scraping a Prometheus client endpoint.

# kube-prometheus-stack has been installed. Check its status by running:
#   kubectl --namespace pulsar-namespace get pods -l "release=pulsar-release"

# Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

# Thank you for installing Apache Pulsar Helm chart version 3.6.0.

# !! WARNING !!

# Important Security Disclaimer for Apache Pulsar Helm Chart Usage:

# This Helm chart is provided with a default configuration that does not
# meet the security requirements for production environments or sensitive
# data handling. Users are strongly advised to thoroughly review and
# customize the security settings to ensure a secure deployment that
# aligns with their specific operational and security policies.

# Go to https://github.com/apache/pulsar-helm-chart for more details.

# Ask usage questions at https://github.com/apache/pulsar/discussions/categories/q-a
# Report issues to https://github.com/apache/pulsar-helm-chart/issues
# Please contribute improvements to https://github.com/apache/pulsar-helm-chart


# 1. Get the application URL by running these commands:
#   export POD_NAME=$(kubectl get pods --namespace pulsar-namespace -l "app.kubernetes.io/name=prometheus-node-exporter,app.kubernetes.io/instance=pulsar-release" -o jsonpath="{.items[0].metadata.name}")
#   echo "Visit http://127.0.0.1:9100 to use your application"
#   kubectl port-forward --namespace pulsar-namespace $POD_NAME 9100