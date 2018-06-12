variable "do_token" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("./id_rsa.pub")}"
}
