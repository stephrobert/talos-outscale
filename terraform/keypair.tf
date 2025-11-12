# Keypair pour l'accès SSH
resource "outscale_keypair" "main" {
  keypair_name = "${var.cluster_name}-keypair"
  public_key   = file(pathexpand(var.ssh_public_key_path))
}
