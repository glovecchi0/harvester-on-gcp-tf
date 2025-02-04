locals {
  sles_startup_script_template_file = "../../modules/harvester/sles_startup_script_sh.tpl"
  sles_startup_script_file          = "${path.cwd}/sles_startup_script.sh"
  data_disk_name                    = "/dev/sd"
  data_disk_mount_point             = "/mnt/datadisk"
  default_ipxe_script_template_file = "../../modules/harvester/default_ipxe.tpl"
  default_ipxe_script_file          = "${path.cwd}/default.ipxe"
  join_ipxe_script_template_file    = "../../modules/harvester/join_ipxe.tpl"
  join_ipxe_script_file             = "${path.cwd}/join.ipxe"
  ipxe_base_url                     = "http://192.168.122.1"
  create_cloud_config_template_file = "../../modules/harvester/create_cloud_config_yaml.tpl"
  create_cloud_config_file          = "${path.cwd}/create_cloud_config.yaml"
  join_cloud_config_template_file   = "../../modules/harvester/join_cloud_config_yaml.tpl"
  join_cloud_config_file            = "${path.cwd}/join_cloud_config.yaml"
  create_ssh_key_pair               = var.create_ssh_key_pair == true ? false : true
  ssh_private_key_path              = var.ssh_private_key_path == null ? "${path.cwd}/${var.prefix}-ssh_private_key.pem" : var.ssh_private_key_path
  ssh_public_key_path               = var.ssh_public_key_path == null ? "${path.cwd}/${var.prefix}-ssh_public_key.pem" : var.ssh_public_key_path
  create_vpc                        = var.create_vpc == true ? false : var.create_vpc
  vpc                               = var.vpc == null ? module.harvester_node.vpc[0].name : var.vpc
  subnet                            = var.subnet == null ? module.harvester_node.subnet[0].name : var.subnet
  create_firewall                   = var.create_firewall == true ? false : var.create_firewall
  ssh_username                      = "sles"
}

resource "local_file" "sles_startup_script_config" {
  content = templatefile("${local.sles_startup_script_template_file}", {
    version     = var.harvester_version,
    count       = var.data_disk_count,
    disk_name   = local.data_disk_name,
    mount_point = local.data_disk_mount_point
  })
  file_permission = "0644"
  filename        = local.sles_startup_script_file
}

data "local_file" "sles_startup_script" {
  depends_on = [local_file.sles_startup_script_config]
  filename   = local.sles_startup_script_file
}

resource "local_file" "default_ipxe_script_config" {
  content = templatefile("${local.default_ipxe_script_template_file}", {
    version = var.harvester_version
    base    = local.ipxe_base_url
  })
  file_permission = "0644"
  filename        = local.default_ipxe_script_file
}

resource "local_file" "create_cloud_config_yaml" {
  content = templatefile("${local.create_cloud_config_template_file}", {
    version  = var.harvester_version
    token    = var.harvester_first_node_token
    password = var.harvester_password
    hostname = "${var.prefix}-1"
  })
  file_permission = "0644"
  filename        = local.create_cloud_config_file
}

/*
resource "local_file" "join_ipxe_script_config" {
  content = templatefile("${local.join_ipxe_script_template_file}", {
    version = var.harvester_version
    base    = local.ipxe_base_url
  })
  file_permission = "0644"
  filename        = local.join_ipxe_script_file
}

resource "local_file" "join_cloud_config_yaml" {
  count = var.instance_count > 1 ? 1 : 0
  content = templatefile("${local.join_cloud_config_template_file}", {
    version  = var.harvester_version,
    token    = var.harvester_first_node_token,
    password = var.harvester_password,
    hostname = "${var.prefix}-1"
  })
  file_permission = "0644"
  filename        = local.join_cloud_config_file
}
*/

module "harvester_node" {
  depends_on            = [local_file.sles_startup_script_config]
  source                = "../../modules/google-cloud/compute-engine"
  prefix                = var.prefix
  project_id            = var.project_id
  region                = var.region
  create_ssh_key_pair   = var.create_ssh_key_pair
  ssh_private_key_path  = local.ssh_private_key_path
  ssh_public_key_path   = local.ssh_public_key_path
  ip_cidr_range         = var.ip_cidr_range
  create_vpc            = var.create_vpc
  vpc                   = var.vpc
  subnet                = var.subnet
  create_firewall       = var.create_firewall
  os_disk_type          = var.os_disk_type
  os_disk_size          = var.os_disk_size
  instance_type         = var.instance_type
  create_data_disk      = var.create_data_disk
  data_disk_count       = var.data_disk_count
  data_disk_type        = var.data_disk_type
  data_disk_size        = var.data_disk_size
  startup_script        = data.local_file.sles_startup_script.content
  nested_virtualization = var.nested_virtualization
}

data "local_file" "ssh_private_key" {
  depends_on = [module.harvester_node]
  filename   = local.ssh_private_key_path
}

resource "null_resource" "harvester_iso_download_checking" {
  depends_on = [data.local_file.ssh_private_key]
  provisioner "remote-exec" {
    inline = [
      "while true; do [ -f '/tmp/harvester_download_done' ] && break || echo 'The download of the Harvester ISO is not yet complete. Checking again in 30 seconds...' && sleep 30; done"
    ]
    connection {
      type        = "ssh"
      host        = module.harvester_node.instances_public_ip[0]
      user        = local.ssh_username
      private_key = data.local_file.ssh_private_key.content
    }
  }
}

resource "null_resource" "copy_files_to_first_node" {
  depends_on = [null_resource.harvester_iso_download_checking]
  for_each = {
    "default.ipxe"                 = local.default_ipxe_script_file
    "create_cloud_config_yaml.tpl" = local.create_cloud_config_file
  }
  connection {
    type        = "ssh"
    host        = module.harvester_node.instances_public_ip[0]
    user        = local.ssh_username
    private_key = data.local_file.ssh_private_key.content
  }
  provisioner "file" {
    source      = each.value
    destination = "/tmp/${basename(each.value)}"
  }
}

resource "null_resource" "harvester_node_startup" {
  depends_on = [null_resource.copy_files_to_first_node]
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/${basename(local.default_ipxe_script_file)} /tmp/${basename(local.create_cloud_config_file)} /srv/www/harvester/",
      "sudo virsh net-define /srv/www/harvester/vlan1.xml",
      "sudo virsh net-start vlan1",
      "sudo virsh net-autostart vlan1"
    ]
    connection {
      type        = "ssh"
      host        = module.harvester_node.instances_public_ip[0]
      user        = local.ssh_username
      private_key = data.local_file.ssh_private_key.content
    }
  }
}
