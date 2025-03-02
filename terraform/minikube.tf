
locals {
    host_data_path     = abspath("../data")
    # https://github.com/kubernetes/minikube/blob/3dae3866bd4370c0f3bef22ace0071f9f83f6193/cmd/storage-provisioner/main.go#L28
    minikube_data_path = "/tmp/hostpath-provisioner" # must be hardcoded
}

resource "terraform_data" "minikube_host_mount_folder" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path} && chmod 777 ${local.host_data_path}" # TODO: add permissions for underlying host
  }
}

resource "terraform_data" "minikube_cluster" {
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  provisioner "local-exec" {
    command = <<EOT
      minikube start --mount-string=${local.host_data_path}:${local.minikube_data_path} --mount
      minikube addons enable metrics-server
      kubectl config use-context minikube
      sleep 15
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube stop; minikube delete;"
  }
}
