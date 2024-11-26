provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

locals {
  host_data_path     = abspath("../data/pulsar")
  minikube_data_path = "/data/pulsar"
  volume_count = 4 # todo: specify volumes as set instead and
}

resource "terraform_data" "minikube_host_mount_folder" {
  count = local.volume_count
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path}/volume_${count.index}"
  }
}

resource "terraform_data" "minikube_cluster" {
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  provisioner "local-exec" {
    command = "minikube start --memory=8192 --cpus=12 --mount-string='${local.host_data_path}:${local.minikube_data_path}' --mount"
    # --gpus='all'
    # --mount=true
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube stop && minikube delete"
  }
}

resource "kubernetes_persistent_volume" "persistent_volume" {
  count = local.volume_count
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  metadata {
    name = "persistent-volume-${count.index}"
  }

  spec {
    capacity = {
      storage = "2Gi"
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_source {
      host_path {
        path = "${local.minikube_data_path}/volume_${count.index}" 
      }
    }
  }
}


resource "helm_release" "pulsar" {
  repository       = "https://pulsar.apache.org/charts"
  chart            = "pulsar"
  version          = "3.7.0"
  name             = "pulsar"
  namespace        = "pulsar"
  create_namespace = true
  values           = [file("pulsar-values.yaml")]
  timeout          = 15 * 60
  set {
    name  = "bookkeeper.storage.hostPath.path"
    value = local.minikube_data_path
  }
  depends_on = [terraform_data.minikube_cluster]
}
