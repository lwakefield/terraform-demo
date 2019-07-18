variable "do_token" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("./id_rsa.pub")}"
}

resource "digitalocean_droplet" "web" {
  count = 3

  name = "web-${count.index}"
  region = "nyc1"
  size = "1gb"
  image = "docker-18-04"
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
  private_networking = true
  tags = [ "demo-web", "demo-web-${count.index}" ]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = "${file("./id_rsa")}"

    bastion_host = "${digitalocean_droplet.jumpserver.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [ "docker run -d -p 80:8000 jwilder/whoami" ]
  }
}

resource "digitalocean_droplet" "jumpserver" {
  name = "jump-server"
  region = "nyc1"
  size = "1gb"
  image = "ubuntu-18-10-x64"
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
  private_networking = true
}

resource "digitalocean_loadbalancer" "public" {
  name = "public-loadbalancer"
  region = "nyc1"

  droplet_tag = "demo-web"

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
  tags = [ "demo-web" ]

  inbound_rule {
    protocol = "tcp"
    port_range = "80"
    source_load_balancer_uids = ["${digitalocean_loadbalancer.public.id}"]
  }
  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_droplet_ids = ["${digitalocean_droplet.jumpserver.id}"]
  }
}
