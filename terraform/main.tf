provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
# TODO: run instalations of soft as part of the terraform script?

resource "terraform_data" "minikube_cluster" {
  provisioner "local-exec" {
    command = "minikube start --memory=8192 --cpus=12"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube stop && minikube delete"
  }
}

locals {
  host_data_path     = "../data/pulsar"
  minikube_data_path = "/data/pulsar"
}

resource "terraform_data" "minikube_host_mount" {
  # this needs to stay alive constantly so we cannon use it in depends_on
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path} && minikube mount ${local.host_data_path}:${local.minikube_data_path}"
  }
  depends_on = [terraform_data.minikube_cluster]
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
