variable "public_ip" {
  type        = string
  description = "The Floating IP of the VM (used for TLS SAN in the Kubeconfig)"
}
