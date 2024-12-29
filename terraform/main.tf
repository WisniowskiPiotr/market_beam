provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

terraform {
  required_providers {
    pulsar = {
      version = "0.4.2"
      source = "registry.terraform.io/streamnative/pulsar"
    }
  }
}

#provider "pulsar" {
#  web_service_url = "http://cluster-broker.test.svc.cluster.local:8080" # TODO: get url from pulsar cluster
#}

