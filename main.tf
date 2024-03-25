variable "oper_system" {
  description = "The target operating system for file download and decompression"
  type        = string
  default     = "linux" #Valid Operating systems are linux, mac and windows
}

variable "architecture" {
  description = "The target architecture for file download and decompression"
  type        = string
  default     = "amd64" #Valid Architectures are amd64, arm64 and ppc64le
}


locals {
  is_windows = var.oper_system == "windows"
  is_mac     = var.oper_system == "mac"
  is_linux   = var.oper_system == "linux"
  is_amd64   = var.architecture == "amd64"
  is_arm64   = var.architecture == "arm64"
  is_ppc64le = var.architecture == "ppc64le"

  client_url    = local.is_arm64 ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-client-${var.oper_system}-${var.architecture}.tar.gz" : (
  local.is_linux && local.is_amd64 ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-client-${var.oper_system}-${var.architecture}.tar.gz" : (
  local.is_linux && local.is_ppc64le ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-client-${var.oper_system}.tar.gz" : "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-client-${var.oper_system}.tar.gz"
  )
  )

  installer_url = local.is_arm64 ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-install-${var.oper_system}-${var.architecture}.tar.gz" : (
  local.is_linux && local.is_amd64 ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-install-${var.oper_system}-${var.architecture}.tar.gz" : (
  local.is_linux && local.is_ppc64le ? "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-install-${var.oper_system}.tar.gz" : "https://mirror.openshift.com/pub/openshift-v4/ppc64le/clients/ocp/stable-${var.ocp_config.ocp_version}/openshift-install-${var.oper_system}.tar.gz"
  )
  )

  client_path    = local.is_arm64 || (local.is_linux && local.is_amd64) ? "./openshift-client-${var.oper_system}-${var.architecture}.tar.gz" : "./openshift-client-${var.oper_system}.tar.gz"
  installer_path = local.is_arm64 || (local.is_linux && local.is_amd64) ? "./openshift-install-${var.oper_system}-${var.architecture}.tar.gz" : "./openshift-install-${var.oper_system}.tar.gz"
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
    command = local.is_windows ? (
    "Copy-Item -Path '.\\*.ign' -Destination '..\\3zoneocp\\'"
    ) : (
    "cp ./*.ign ../3zoneocp/"
    )
  }
}

resource "null_resource" "create_kube_directory" {
  provisioner "local-exec" {
    command = local.is_windows ? ( "$kubeConfigDir = [System.Environment]::GetFolderPath('UserProfile') + '\\.kube'; if (!(Test-Path $kubeConfigDir)) { New-Item -ItemType Directory -Path $kubeConfigDir | Out-Null }" ) : ( "mkdir -p ~/.kube" )
  }
}

resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.create_ignition_configs, null_resource.create_kube_directory]

  provisioner "local-exec" {
    command = local.is_windows ? ( "$kubeConfigPath = [System.Environment]::GetFolderPath('UserProfile') + '\\.kube\\config'; Copy-Item -Path '.\\auth\\kubeconfig' -Destination $kubeConfigPath" ) : ( "cp ./auth/kubeconfig ~/.kube/config" )
  }
}