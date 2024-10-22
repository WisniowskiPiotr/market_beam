provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "terraform_data" "minikube_cluster" {
  provisioner "local-exec" {
    command = "minikube start --memory=8192 --cpus=12"
  }

  provisioner "local-exec" {
    when = destroy
    command = "minikube stop && minikube delete"
  }
}

resource "helm_release" "zookeeper" {
  name       = "zookeeper"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "zookeeper"
  version    = "13.4.15"

  set {
    name  = "replicaCount"
    value = 1
  }

  depends_on = [
    terraform_data.minikube_cluster
  ]
}

resource "helm_release" "kafka" {
  name       = "kafka"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  version    = "30.1.6"

  set {
    name  = "replicaCount"
    value = 1
  }
  set {
    name  = "controller.replicaCount"
    value = 1
  }

  # below is for external communication from kafka, not needed for local testing -> port forward better
  # set {
  #   name  = "externalAccess.enabled"
  #   value = "true"
  # }

  # set {
  #   name  = "externalAccess.controller.service.type"
  #   value = "NodePort"
  # }

  # set {
  #   name  = "externalAccess.controller.service.nodePorts[0]"
  #   value = "30092"
  # }

  set {
    name  = "sasl.client.users[0]"
    value = "test-user"
  }

  set {
    name  = "sasl.client.passwords[0]"
    value = "test-user-password"
  }

  set {
    name  = "zookeeper.enabled"
    value = "false"  # Since we're using a separate Zookeeper release
  }

  depends_on = [
    helm_release.zookeeper
  ]
}
