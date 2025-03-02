
locals {
    host_data_path     = abspath("../data")
    minikube_data_path = "/cluster-data"
}

resource "terraform_data" "minikube_host_mount_folder" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path} && chmod 777 ${local.host_data_path}"
  }
}

resource "terraform_data" "minikube_cluster" {
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  provisioner "local-exec" {
    # --mount-uid 82 --mount-gid 82
    command = <<EOT
      minikube start \
        --mount-string=${local.host_data_path}:${local.minikube_data_path} \
        --mount \
        --memory=8g \
        --cpus=12
      minikube addons enable metrics-server
      kubectl config use-context minikube
      sleep 15
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      minikube stop
      minikube delete
    EOT
  }
}
