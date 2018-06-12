variable "do_token" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("./id_rsa.pub")}"
}

resource "digitalocean_droplet" "server" {
  count = 3
  name = "server-${count.index}"
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

resource "digitalocean_droplet" "jumpserver" {
  name = "jump-server"
  region = "nyc1"
  size = "1gb"
  image = "ubuntu-16-04-x64"
  ssh_keys = [
    "${digitalocean_ssh_key.default.id}"
  ]
  private_networking = true
}

resource "digitalocean_loadbalancer" "public" {
  name = "public-loadbalancer"
  region = "nyc1"

  droplet_ids = ["${digitalocean_droplet.server.*.id}"]

  forwarding_rule {
    entry_port = 80
    entry_protocol = "http"
    target_port = 80
    target_protocol = "http"
  }

  healthcheck {
    port = 80
    protocol = "tcp"
  }
}

resource "digitalocean_firewall" "firewall" {
  name = "server-firewall"
  droplet_ids = ["${digitalocean_droplet.server.*.id}"]

  inbound_rule = [
    {
      protocol = "tcp"
      port_range = "80"
      source_load_balancer_uids = ["${digitalocean_loadbalancer.public.id}"]
    },
    {
      protocol = "tcp"
      port_range = "22"
      source_droplet_ids = ["${digitalocean_droplet.jumpserver.id}"]
    }
  ]
  outbound_rule = [
    {
      protocol = "tcp"
      port_range = "80"
      destination_load_balancer_uids = ["${digitalocean_loadbalancer.public.id}"]
    },
    {
      protocol = "tcp"
      port_range = "22"
      destination_droplet_ids = ["${digitalocean_droplet.jumpserver.id}"]
    }
  ]
}
