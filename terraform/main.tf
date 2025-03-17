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

provider "pulsar" {
  web_service_url = file(terraform_data.pulsar_manager_url.output[0])
  # todo get token from pulsar for auth
  #key_file_path = "./jwtRS256.key.pub"
  #token             = filebase64("./admin.jwtRS256.key")
}


#https://github.com/apache/pulsar-helm-chart/blob/master/charts/pulsar/values.yaml#L1807

# https://pulsar.apache.org/docs/4.0.x/helm-deploy/#access-pulsar-cluster
# change pulsar manager to nodeport and graphana too
