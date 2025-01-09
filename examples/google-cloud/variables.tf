variable "prefix" {
  description = "Prefix added to names of all resources"
  type        = string
  default     = "gcp-tf"
}

variable "project_id" {
  description = "Google Project ID that will contain all created resources"
  type        = string
  default     = "gcp-tf"
}

variable "region" {
  description = "Google region used for all resources"
  type        = string
  default     = "us-west2"

  validation {
    condition = contains([
      "asia-east1",
      "asia-east2",
      "asia-northeast1",
      "asia-northeast2",
      "asia-northeast3",
      "asia-south1",
      "asia-south2",
      "asia-southeast1",
      "asia-southeast2",
      "australia-southeast1",
      "australia-southeast2",
      "europe-central2",
      "europe-north1",
      "europe-southwest1",
      "europe-west1",
      "europe-west10",
      "europe-west12",
      "europe-west2",
      "europe-west3",
      "europe-west4",
      "europe-west6",
      "europe-west8",
      "europe-west9",
      "me-central1",
      "me-central2",
      "me-west1",
      "northamerica-northeast1",
      "northamerica-northeast2",
      "southamerica-east1",
      "southamerica-west1",
      "us-central1",
      "us-east1",
      "us-east4",
      "us-east5",
      "us-south1",
      "us-west1",
      "us-west2",
      "us-west3",
      "us-west4"
    ], var.region)
    error_message = "Invalid Region specified!"
  }
}

variable "create_ssh_key_pair" {
  description = "Specify if a new SSH key pair needs to be created for the instances"
  type        = bool
  default     = true
}

variable "ssh_private_key_path" {
  description = "The full path where is present the pre-generated SSH PRIVATE key (not generated by Terraform)"
  type        = string
  default     = null
}

variable "ssh_public_key_path" {
  description = "The full path where is present the pre-generated SSH PUBLIC key (not generated by Terraform)"
  type        = string
  default     = null
}

variable "ip_cidr_range" {
  description = "Range of private IPs available for the Google Subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "create_vpc" {
  description = "Specify whether VPC / Subnet should be created for the instances"
  type        = bool
  default     = true
}

variable "vpc" {
  description = "Google VPC used for all resources"
  type        = string
  default     = null
}

variable "subnet" {
  description = "Google Subnet used for all resources"
  type        = string
  default     = null
}

variable "create_firewall" {
  description = "Google Firewall used for all resources"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "The number of server nodes"
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.instance_count)
    error_message = "Invalid number of server nodes! Valid values are 1, 3, or 5 (for ETCD quorum)."
  }
}

variable "instance_disk_size" {
  description = "Size of the disk attached to each node, specified in GB"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Type of the disk attached to each node (e.g. 'pd-standard', 'pd-ssd' or 'pd-balanced')"
  type        = string
  default     = "pd-balanced"
}

variable "instance_type" {
  description = "The name of a Google Compute Engine machine type"
  type        = string
  default     = "n2-standard-16"
}

variable "os_type" {
  description = "Operating system type (sles or ubuntu)"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["sles", "ubuntu"], var.os_type)
    error_message = "The operating system type must be 'sles' or 'ubuntu'."
  }
}

variable "startup_script" {
  description = "Custom startup script"
  type        = string
  default     = <<EOT
# Enable connection to the VM's Serial Console
systemctl start serial-getty@ttyS1.service
systemctl enable serial-getty@ttyS1.service
# Installation of pre-requisite packages
apt update && sudo apt upgrade -y
apt install -y curl wget nfs-common qemu-kvm libvirt-clients libvirt-daemon-system cpu-checker virtinst novnc websockify
# Harvester's ISO download
wget https://releases.rancher.com/harvester/v1.3.1/harvester-v1.3.1-amd64.iso -O /var/lib/libvirt/images/harvester.iso
# Data disk partition
parted /dev/sdb mklabel gpt
parted /dev/sdb mkpart primary ext4 0% 100%
mkfs.ext4 /dev/sdb1
mkdir /mnt/newdisk
mount /dev/sdb1 /mnt/newdisk
echo "/dev/sdb1 /mnt/newdisk ext4 defaults 0 0" | sudo tee -a /etc/fstab
EOT
}

variable "nested_virtualization" {
  description = "Defines whether the instance should have nested virtualization enabled"
  type        = bool
  default     = true
}
