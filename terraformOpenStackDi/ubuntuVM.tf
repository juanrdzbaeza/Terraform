## 1. Generate the token to connect to OpenStack
## curl -X POST http://192.168.64.12:5000/v2.0/tokens -d '{"auth":{"passwordCredentials":{"username":"jrb085", "password":"******"}, "tenantId":"************"}}' -H 'Content-type: application/json' > token.json
variable "user_name" {default = "jrb085"}

## 2. Abrir el archivo token.json generado en la operación curl y copiar el token de acceso

variable "my_token" {
  default = ""          ## Token generado (temporal)
}

variable "project_name" {
  default = "jrb085"     ## Nombre del proyecto en OpenStack / provider tenant_name
}
variable "project_network" {
  default = "jrb085-net"  ## Nombre de la rede en Opentstack / network name
}



# Configure the OpenStack Provider
provider "openstack" {
  user_name   = "${var.user_name}"
  tenant_name = "${var.project_name}"
  token 	  = "${var.my_token}"
  auth_url    = "http://192.168.64.12:5000/v3/"
  region      = "RegionOne"
}


########################################
# Crear la Virtual Machine
########################################

resource "openstack_compute_instance_v2" "mi_tf_instance" {
  name      = "ansible-dev"
  availability_zone = "nova"
  image_id  = "9eabea01-c377-4911-9ee0-7276ae4ca820"    ## Ubuntu 18
  flavor_name = "medium"
  key_pair  = "${var.user_name}"
  security_groups = ["default"]
  
  network {
    name = "${var.project_network}"
  }

}

# Crear una IP de mi pool ext-net

resource "openstack_networking_floatingip_v2" "myip" {
  pool = "ext-net"
}

# Asociar la IP
resource "openstack_compute_floatingip_associate_v2" "myip_as" {
  floating_ip = "${openstack_networking_floatingip_v2.myip.address}"
  instance_id = "${openstack_compute_instance_v2.mi_tf_instance.id}"

  provisioner "file" {
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key  = "${file("/Users/juan/.ssh/id_rsa")}"
      host = "${openstack_networking_floatingip_v2.myip.address}"
    }

    // En una carpeta local tengo creado un par de claves (especifico) para ansible.
    source      = "/Users/juan/.ssh/"    ## copia todos los archivos de la carpeta
    destination = "/home/ubuntu/.ssh"
  }
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key  = "${file("/Users/juan/.ssh/id_rsa")}"
      host = "${openstack_networking_floatingip_v2.myip.address}"
    }
    inline = [
      "sudo apt-get update -y",
 ##     "sudo apt-get upgrade -y",
      "sudo apt-get install -y python-minimal",
      "sudo more /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys",  ## inyecto la clave publica en authorized_keys
      ## Los siguientes comandos instalan ansible (solo ejecutar en la máquina de control ansible-dev)
      "sudo apt-get install -y software-properties-common", 
      "sudo apt-add-repository --yes --update ppa:ansible/ansible", 
      "sudo apt-get install -y ansible"
      ]
    on_failure = "continue"
  }

}

## Copiar la plantilla de la máquina virtual "ansible-dev" para crear los nodos "node-1", "node-2"
## Importante: en los nodos se ha de:
##  1. Copiar solamente la clave pública id_rsa.pub
##        source      = "c:/DDatos msi/ansible/ansible_ssh_keypair/id_rsa.pub"
##  2. Instalar solamente 
##        python-minimal
##  3. Inyectar la clave publica id_rsa.pub en authorized_keys
## 