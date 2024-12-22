provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "pulsar" {
  web_service_url = "http://cluster-broker.test.svc.cluster.local:8080" # TODO: get url from pulsar cluster
}