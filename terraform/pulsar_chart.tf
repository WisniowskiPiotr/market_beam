

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
  timeout          = 15 * 60
  #depends_on = [kubernetes_persistent_volume.pulsar_persistent_volume]
  depends_on = [terraform_data.minikube_cluster]
}
