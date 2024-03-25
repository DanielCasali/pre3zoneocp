variable "oper_system" {
  description = "The target operating system for file download and decompression"
  type        = string
  default     = "linux"
}

variable "architecture" {
  description = "The target architecture for file download and decompression"
  type        = string
  default     = "amd64"
}

variable "ocp_version" {
  description = "The version of OpenShift Container Platform"
  type        = string
}

locals {
  is_windows = var.oper_system == "windows"
  is_mac     = var.oper_system == "mac"
  is_linux   = var.oper_system == "linux"
  is_amd64   = var.architecture == "amd64"
  is_arm64   = var.architecture == "arm64"
  is_ppc64le = var.architecture == "ppc64le"

  client_url    = local.is_linux && local.is_ppc64le ? "https://mirror.openshift.com/pub/openshift-v4/${var.architecture}/clients/ocp/stable-${var.ocp_version}/openshift-client-${var.oper_system}.tar.gz" : "https://mirror.openshift.com/pub/openshift-v4/${var.architecture}/clients/ocp/stable-${var.ocp_version}/openshift-client-${var.oper_system}-${var.architecture}.tar.gz"
  installer_url = local.is_linux && local.is_ppc64le ? "https://mirror.openshift.com/pub/openshift-v4/${var.architecture}/clients/ocp/stable-${var.ocp_version}/openshift-install-${var.oper_system}.tar.gz" : "https://mirror.openshift.com/pub/openshift-v4/${var.architecture}/clients/ocp/stable-${var.ocp_version}/openshift-install-${var.oper_system}-${var.architecture}.tar.gz"
  client_path    = local.is_linux && local.is_ppc64le ? "./openshift-client-${var.oper_system}.tar.gz" : "./openshift-client-${var.oper_system}-${var.architecture}.tar.gz"
  installer_path = local.is_linux && local.is_ppc64le ? "./openshift-install-${var.oper_system}.tar.gz" : "./openshift-install-${var.oper_system}-${var.architecture}.tar.gz"
  output_path    = "./"
}

resource "null_resource" "download_decompress_client" {
  provisioner "local-exec" {
    command = local.is_windows ? (
      local.is_amd64 ? "powershell.exe -Command \"Invoke-WebRequest -Uri '${local.client_url}' -OutFile '${local.client_path}'; tar -xzf '${local.client_path}' -C '${local.output_path}'; Remove-Item '${local.client_path}'\"" : "echo 'Unsupported architecture for Windows'"
    ) : (
      local.is_mac ? (
        local.is_amd64 || local.is_arm64 ? "curl -L -o ${local.client_path} '${local.client_url}' && tar -xzf ${local.client_path} -C '${local.output_path}' && rm ${local.client_path}" : "echo 'Unsupported architecture for Mac'"
      ) : (
        local.is_linux ? (
          local.is_amd64 || local.is_ppc64le ? "curl -O '${local.client_url}' && tar -xzf ${local.client_path} -C '${local.output_path}' && rm ${local.client_path}" : "echo 'Unsupported architecture for Linux'"
        ) : "echo 'Unsupported operating system'"
      )
    )
  }
}

resource "null_resource" "download_decompress_installer" {
  provisioner "local-exec" {
    command = local.is_windows ? (
      local.is_amd64 ? "powershell.exe -Command \"Invoke-WebRequest -Uri '${local.installer_url}' -OutFile '${local.installer_path}'; tar -xzf '${local.installer_path}' -C '${local.output_path}'; Remove-Item '${local.installer_path}'\"" : "echo 'Unsupported architecture for Windows'"
    ) : (
      local.is_mac ? (
        local.is_amd64 || local.is_arm64 ? "curl -L -o ${local.installer_path} '${local.installer_url}' && tar -xzf ${local.installer_path} -C '${local.output_path}' && rm ${local.installer_path}" : "echo 'Unsupported architecture for Mac'"
      ) : (
        local.is_linux ? (
          local.is_amd64 || local.is_ppc64le ? "curl -O '${local.installer_url}' && tar -xzf ${local.installer_path} -C '${local.output_path}' && rm ${local.installer_path}" : "echo 'Unsupported architecture for Linux'"
        ) : "echo 'Unsupported operating system'"
      )
    )
  }
}


locals {
  pull_secret = file(var.pull_secret_file)
  ssh_public_key = file("${path.module}/${var.ssh_public_key_file}")

  install_config = {
    apiVersion = "v1"
    baseDomain = "${var.ocp_config.ocp_cluster_domain}"
    proxy = {
      httpProxy  = "http://proxy.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain}:8080"
      httpsProxy = "http://proxy.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain}:8080"
      noProxy    = ".apps.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},api.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},api-int.${var.ocp_config.ocp_cluster_name}.${var.ocp_config.ocp_cluster_domain},${var.region_entries.zone1.vpc_zone_cidr},${var.region_entries.zone2.vpc_zone_cidr},${var.region_entries.zone3.vpc_zone_cidr},${var.region_entries.zone1.pvs_dc_cidr},${var.region_entries.zone2.pvs_dc_cidr},${var.region_entries.zone3.pvs_dc_cidr}"
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
    sshKey = local.ssh_public_key
  }
}

resource "local_file" "install_config" {
  content  = yamlencode(local.install_config)
  filename = "./install-config.yaml"
}
