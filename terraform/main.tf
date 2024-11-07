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
    when = destroy
    command = "minikube stop && minikube delete"
  }
}

resource "helm_release" "pulsar" {
  name       = "pulsar"
  repository = "https://pulsar.apache.org/charts"
  chart      = "pulsar"
  #namespace  = "pulsar-namespace"
  version    = "3.7.0"
  values     = [file("pulsar-values.yaml")]
  depends_on = [ terraform_data.minikube_cluster ]
}
