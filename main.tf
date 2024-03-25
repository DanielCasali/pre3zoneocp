


locals {
  is_mac     = var.oper_system == "mac"
  is_linux   = var.oper_system == "linux"
  is_amd64   = var.architecture == "amd64"
  is_arm64   = var.architecture == "arm64"
  is_ppc64le = var.architecture == "ppc64le"

  arch_suffix    = local.is_arm64 || (local.is_linux && local.is_amd64) ? "-${var.architecture}" : ""
  file_suffix    = local.is_linux && local.is_ppc64le ? "" : local.arch_suffix
  base_url       = "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}"

  client_url     = "${local.base_url}/openshift-client-${var.oper_system}${local.file_suffix}.tar.gz"
  installer_url  = "${local.base_url}/openshift-install-${var.oper_system}${local.file_suffix}.tar.gz"
  client_path    = "./openshift-client-${var.oper_system}${local.file_suffix}.tar.gz"
  installer_path = "./openshift-install-${var.oper_system}${local.file_suffix}.tar.gz"
  output_path    = "./"

}

resource "null_resource" "download_decompress_client" {
  provisioner "local-exec" {
    command = local.is_mac ? (
    "curl -L -o ${local.client_path} '${local.client_url}' && tar -xzf ${local.client_path} -C '${local.output_path}' && rm ${local.client_path}"
    ) : (
    local.is_linux ? (
    "curl -O '${local.client_url}' && tar -xzf ${local.client_path} -C '${local.output_path}' && rm ${local.client_path}"
    ) : "echo 'Unsupported operating system'"
    )
  }
}

resource "null_resource" "download_decompress_installer" {
  provisioner "local-exec" {
    command = local.is_mac ? (
    "curl -L -o ${local.installer_path} '${local.installer_url}' && tar -xzf ${local.installer_path} -C '${local.output_path}' && rm ${local.installer_path}"
    ) : (
    local.is_linux ? (
    "curl -O '${local.installer_url}' && tar -xzf ${local.installer_path} -C '${local.output_path}' && rm ${local.installer_path}"
    ) : "echo 'Unsupported operating system'"
    )
  }
}


locals {
  pull_secret = file("${path.module}/pull-secret")
  install_config = {
    apiVersion = "v1"
    baseDomain = "${var.ocp_config.ocp_cluster_domain}"
    proxy = {
      httpProxy  = "http://proxy.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain}:8080"
      httpsProxy = "http://proxy.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain}:8080"
      noProxy    = ".apps.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},api.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},api-int.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},${var.region_definition.zone1.vpc_zone_cidr},${var.region_definition.zone2.vpc_zone_cidr},${var.region_definition.zone3.vpc_zone_cidr},${var.region_definition.zone1.pvs_dc_cidr},${var.region_definition.zone2.pvs_dc_cidr},${var.region_definition.zone3.pvs_dc_cidr}"
    }
    compute = [
      {
        hyperthreading = "Enabled"
        name           = "worker"
        replicas       = 3
        architecture   = "ppc64le"
      }
    ]
    controlPlane = {
      hyperthreading = "Enabled"
      name           = "master"
      replicas       = 3
      architecture   = "ppc64le"
    }
    metadata = {
      name = "${var.ocp_config.ocp_cluster_name}"
    }
    networking = var.ocp_config.networking
    platform = {
      none = {}
    }
    pullSecret = local.pull_secret
    sshKey = "${var.pi_ssh_key}"
  }
}

resource "local_file" "install_config" {
  content  = yamlencode(local.install_config)
  filename = "./install-config.yaml"
}

resource "null_resource" "create_manifests" {
  depends_on = [null_resource.download_decompress_installer]
  provisioner "local-exec" {
    command = "./openshift-install create manifests"
  }
}

resource "null_resource" "create_ignition_configs" {
  depends_on = [null_resource.create_manifests]

  provisioner "local-exec" {
    command = "./openshift-install create ignition-configs"
  }
}

resource "null_resource" "copy_ign_files" {
  depends_on = [null_resource.create_ignition_configs]
  provisioner "local-exec" {
    command = "cp ./*.ign ../3zoneocp/"
  }
}

resource "null_resource" "create_kube_directory" {
  provisioner "local-exec" {
    command = "mkdir -p ~/.kube"
  }
}

resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.create_ignition_configs, null_resource.create_kube_directory]

  provisioner "local-exec" {
    command = "cp ./auth/kubeconfig ~/.kube/config"
  }
}