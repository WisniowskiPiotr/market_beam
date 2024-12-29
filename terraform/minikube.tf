
locals {
    host_data_path     = abspath("../data")
    # https://github.com/kubernetes/minikube/blob/3dae3866bd4370c0f3bef22ace0071f9f83f6193/cmd/storage-provisioner/main.go#L28
    minikube_data_path = "/tmp/hostpath-provisioner" # "/data"
    #pulsar_data_volumes = toset(["pulsar_volume_0", "pulsar_volume_1", "pulsar_volume_2", "pulsar_volume_3"])
    #pulsar_zk_volumes = toset(["zk_volume_0", "zk_volume_1", "zk_volume_2", "zk_volume_3"])
}

resource "terraform_data" "minikube_host_mount_folder" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.host_data_path}"
  }
}

resource "terraform_data" "minikube_cluster" {
  depends_on = [ terraform_data.minikube_host_mount_folder ]
  provisioner "local-exec" {
    command = <<EOT
      minikube start --mount-string=${local.host_data_path}:${local.minikube_data_path} --mount
      minikube addons enable metrics-server
      minikube addons enable storage-provisioner
      kubectl config use-context minikube
    EOT
    # --gpus='all' --cpus=12 --memory=8192 
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube stop; minikube delete;"
  }
}
