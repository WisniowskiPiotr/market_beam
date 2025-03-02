
locals {
    host_data_path     = abspath("../data")
    # https://github.com/kubernetes/minikube/blob/3dae3866bd4370c0f3bef22ace0071f9f83f6193/cmd/storage-provisioner/main.go#L28
    minikube_data_path = "/tmp/hostpath-provisioner" # must be hardcoded
}

resource "terraform_data" "minikube_host_mount_folder" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path} && chmod 777 ${local.host_data_path}"
  }
}

resource "terraform_data" "minikube_cluster" {
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  provisioner "local-exec" {
    command = <<EOT
      minikube start --mount-string=${local.host_data_path}:${local.minikube_data_path} --mount --mount-uid 82 --mount-gid 82
      minikube addons enable metrics-server
      kubectl config use-context minikube
      minikube ssh "sudo chmod -R 777 /tmp/hostpath-provisioner/"
      minikube ssh "sudo chmod -R 777 /tmp/hostpath_pv/"
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
