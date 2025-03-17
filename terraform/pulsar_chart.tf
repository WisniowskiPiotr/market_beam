

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

locals {
  bookies_count = 1
  zk_count = 1
}

resource "kubernetes_persistent_volume" "pulsar_zk_volume" {
  count =  local.zk_count
  depends_on = [ terraform_data.minikube_cluster ]
  metadata {
    name = "pulsar-zk-volume-${count.index}"
  }

  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    claim_ref {
      name = "pulsar-release-zookeeper-data-pulsar-release-zookeeper-${count.index}"
      namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
    }
    persistent_volume_source {
      host_path {
        path = "${local.minikube_data_path}/pulsar-zk-volume-${count.index}" 
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "terraform_data" "pulsar_zk_volume_cleanup" {
  count =  local.zk_count
  depends_on = [ kubernetes_persistent_volume.pulsar_zk_volume ]
  provisioner "local-exec" {
    command = <<EOT
      sleep 60
      minikube ssh "sudo chmod -R 777 ${local.minikube_data_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      kubectl delete pvc \
        "pulsar-release-zookeeper-data-pulsar-release-zookeeper-${count.index}" \
        --grace-period=0 --force \
        -n pulsar-namespace
    EOT
  }
}

resource "kubernetes_persistent_volume" "pulsar_journal_volume" {
  count =  local.bookies_count
  depends_on = [ terraform_data.minikube_cluster ]
  metadata {
    name = "pulsar-journal-volume-${count.index}"
  }

  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    claim_ref {
      name = "pulsar-release-bookie-journal-pulsar-release-bookie-${count.index}"
      namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
    }
    persistent_volume_source {
      host_path {
        path = "${local.minikube_data_path}/pulsar-journal-volume-${count.index}" 
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "terraform_data" "pulsar_journal_volume_cleanup" {
  count =  local.zk_count
  depends_on = [ kubernetes_persistent_volume.pulsar_journal_volume ]
  provisioner "local-exec" {
    command = <<EOT
      sleep 60
      minikube ssh "sudo chmod -R 777 ${local.minikube_data_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      kubectl delete pvc \
        "pulsar-release-bookie-journal-pulsar-release-bookie-${count.index}" \
        --grace-period=0 --force \
        -n pulsar-namespace
    EOT
  }
}

resource "kubernetes_persistent_volume" "pulsar_ledger_volume" {
  count =  local.bookies_count
  depends_on = [ terraform_data.minikube_cluster ]
  metadata {
    name = "pulsar-ledger-volume-${count.index}"
  }

  spec {
    capacity = {
      storage = "50Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    claim_ref {
      name = "pulsar-release-bookie-ledgers-pulsar-release-bookie-${count.index}"
      namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
    }
    persistent_volume_source {
      host_path {
        path = "${local.minikube_data_path}/pulsar-ledger-volume-${count.index}" 
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "terraform_data" "pulsar_ledger_volume_cleanup" {
  count =  local.zk_count
  depends_on = [ kubernetes_persistent_volume.pulsar_ledger_volume ]
  provisioner "local-exec" {
    command = <<EOT
      sleep 60
      minikube ssh "sudo chmod -R 777 ${local.minikube_data_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      kubectl delete pvc \
        "pulsar-release-bookie-ledgers-pulsar-release-bookie-${count.index}" \
        --grace-period=0 --force \
        -n pulsar-namespace
    EOT
  }
}


resource "kubernetes_persistent_volume" "pulsar_manager_volume" {
  depends_on = [ terraform_data.minikube_cluster ]
  metadata {
    name = "pulsar-manager-volume"
  }

  spec {
    capacity = {
      storage = "128Mi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    claim_ref {
      name = "pulsar-release-pulsar-manager-data-pulsar-release-pulsar-manager-0"
      namespace = kubernetes_namespace.pulsar_namespace.metadata[0].name
    }
    persistent_volume_source {
      host_path {
        path = "${local.minikube_data_path}/pulsar-manager-volume" 
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "terraform_data" "pulsar_manager_volume_cleanup" {
  count =  local.zk_count
  depends_on = [ kubernetes_persistent_volume.pulsar_ledger_volume ]
  provisioner "local-exec" {
    command = <<EOT
      sleep 60
      minikube ssh "sudo chmod -R 777 ${local.minikube_data_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      kubectl delete pvc \
        "pulsar-release-pulsar-manager-data-pulsar-release-pulsar-manager-0" \
        --grace-period=0 --force \
        -n pulsar-namespace
    EOT
  }
}


resource "helm_release" "pulsar" {
  repository       = "https://pulsar.apache.org/charts"
  chart            = "pulsar"
  version          = "3.6.0"
  name             = local.pulsar_release_name
  namespace        = kubernetes_namespace.pulsar_namespace.metadata[0].name
  values           = [file("pulsar_chart_values.yaml")]
  
  set {
    name  = "zookeeper.replicaCount"
    value = local.zk_count
  }

  set {
    name  = "zookeeper.volumes.data.size"
    value = kubernetes_persistent_volume.pulsar_zk_volume[0].spec[0].capacity.storage
  }

  set {
    name  = "bookkeeper.replicaCount"
    value = local.bookies_count
  }

  set {
    name  = "bookkeeper.volumes.journal.size"
    value = kubernetes_persistent_volume.pulsar_journal_volume[0].spec[0].capacity.storage
  }

  set {
    name  = "bookkeeper.volumes.ledger.size"
    value = kubernetes_persistent_volume.pulsar_ledger_volume[0].spec[0].capacity.storage
  }
  timeout          = 10 * 60
  cleanup_on_fail = true
  depends_on = [terraform_data.minikube_cluster]
}


resource "terraform_data" "pulsar_manager_url" {
  depends_on = [ helm_release.pulsar ]
  input = [
    "minikube.ip.key"
  ]
  provisioner "local-exec" {
    command = <<EOT
      echo -n http://$(minikube ip):$(kubectl get service pulsar-release-pulsar-manager -n pulsar-namespace -o jsonpath='{.spec.ports[0].nodePort}') > minikube.ip.key
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      rm minikube.ip.key
    EOT
  }
}

# secret to acess manager:  kubectl get secret -l component=pulsar-manager -o=jsonpath="{.items[0].data.UI_PASSWORD}" -n pulsar-namespace | base64 --decode
#user pulsar