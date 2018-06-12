variable "do_token" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("./id_rsa.pub")}"
}

resource "digitalocean_droplet" "server" {
  name = "server"
  region = "nyc1"
  size = "1gb"
  image = "docker-16-04"
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
  private_networking = true

  provisioner "remote-exec" {
    inline = [
      "docker run -d -p 80:8000 jwilder/whoami"
    ]
  }
}
