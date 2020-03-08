# -*- mode: ruby -*-
# vi: set ft=ruby :

# Copyright 2019 Jonathan T. Moore
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "ubuntu/xenial64"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  config.vm.network "forwarded_port", guest: 8080, host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8200, host: 8200, host_ip: "127.0.0.1"
  
  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
  end

  # View the documentation for the provider you are using for more
  # information on available options.

  config.vm.provision "file", source: "docker-compose.yml.template", destination: "docker-compose.yml.template"
  config.vm.provision "file", source: "vault-unseal.sh", destination: "vault-unseal.sh"
  config.vm.provision "file", source: "concourse-policy.hcl", destination: "concourse-policy.hcl"
  config.vm.provision "file", source: "admins-policy.hcl", destination: "admins-policy.hcl"

  config.vm.synced_folder "concourse-data", "/opt/concourse-data", create: true, type: "smb", mount_options: ["uid=999","forceuid","file_mode=0700","dir_mode=0700"]
  config.vm.synced_folder "vault-data", "/opt/vault-data", create: true
  
  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", env: { "CONCOURSE_ADD_LOCAL_USER" => ENV['CONCOURSE_ADD_LOCAL_USER'], "VAULT_ADMIN_USERPASS" => ENV['VAULT_ADMIN_USERPASS'] }, inline: <<-SHELL
    set -x
    set -e

    if [ -z "$CONCOURSE_ADD_LOCAL_USER" ]; then echo "Set CONCOURSE_ADD_LOCAL_USER"; exit 1; fi
    CONCOURSE_MAIN_TEAM_LOCAL_USER=`echo $CONCOURSE_ADD_LOCAL_USER | cut -d : -f 1`
    if [ -z "$VAULT_ADMIN_USERPASS" ]; then echo "Set VAULT_ADMIN_USERPASS"; exit 1; fi
    VAULT_ADMIN_USER=`echo $VAULT_ADMIN_USERPASS | cut -d : -f 1`
    VAULT_ADMIN_PASS=`echo $VAULT_ADMIN_USERPASS | cut -d : -f 2`

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    
    apt-get update
    apt-get -y upgrade
    apt-get install -y docker-ce docker-compose
    usermod -aG docker vagrant

    apt-get -y install unzip openssl ntp

    wget -q https://releases.hashicorp.com/vault/1.1.2/vault_1.1.2_linux_amd64.zip
    unzip vault_*.zip
    mkdir -p /usr/local/bin
    mv vault /usr/local/bin

    iface=`ifconfig -s | cut -d ' ' -f 1 | egrep  '^enp'`
    ipaddr=`ip addr show | awk '/'$iface'/ { ready=1 } ready && /inet / { print $2; ready=0}' | cut -d / -f 1`

    mv vault-unseal.sh /usr/local/bin
    chmod +x /usr/local/bin/vault-unseal.sh

    if [ -f /opt/concourse-data/postgres_user ]; then
      export CONCOURSE_POSTGRES_PASSWORD=`cat /opt/concourse-data/postgres_user`
    else
      export CONCOURSE_POSTGRES_PASSWORD=`openssl rand -hex 12`
      echo -n "$CONCOURSE_POSTGRES_PASSWORD" > /opt/concourse-data/postgres_user
    fi

    # N.B. First time around we generate a random token until we have
    # properly initialized Vault
    export CONCOURSE_VAULT_CLIENT_TOKEN=`openssl rand -hex 12`

    cat docker-compose.yml.template | \
      sed -e 's/%CONCOURSE_POSTGRES_PASSWORD/'${CONCOURSE_POSTGRES_PASSWORD}'/g' | \
      sed -e 's/%CONCOURSE_ADD_LOCAL_USER%/'${CONCOURSE_ADD_LOCAL_USER}'/g' | \
      sed -e 's/%CONCOURSE_MAIN_TEAM_LOCAL_USER%/'${CONCOURSE_MAIN_TEAM_LOCAL_USER}'/g' | \
      sed -e 's/%CONCOURSE_VAULT_CLIENT_TOKEN%/'${CONCOURSE_VAULT_CLIENT_TOKEN}'/g' > docker-compose.yml

    docker-compose up -d

    i=1
    while ! nc -zv 127.0.0.1 8200; do
      i=$((i+1))
      echo "Waiting for Vault to listen on port (attempt $i)..."
      true
    done
      
    VAULT_ADDR=http://127.0.0.1:8200; export VAULT_ADDR
    i=1
    while true; do
      status=$(vault status >/dev/null 2>&1; echo $?)
      if [ "$status" != 1 ]; then
        break
      fi
      i=$((i+1))
      echo "Waiting for Vault to report status (attempt $i)..."
      sleep 1
    done      

    if [ ! -f /opt/vault-data/init.log ]; then

      VAULT_ADDR=http://127.0.0.1:8200 vault operator init > /opt/vault-data/init.log
      /usr/local/bin/vault-unseal.sh
      vault login `cat /opt/vault-data/init.log | awk '/Initial Root Token/ { print $4}'`
      vault secrets enable -version=1 -path=concourse kv

      vault policy write concourse concourse-policy.hcl
      vault policy write admins admins-policy.hcl
      vault auth enable userpass
      vault write auth/userpass/users/$VAULT_ADMIN_USER password=$VAULT_ADMIN_PASS policies=admins
    else
      /usr/local/bin/vault-unseal.sh
      vault login `cat /opt/vault-data/init.log | awk '/Initial Root Token/ { print $4}'`
    fi

    mkdir -p /etc/concourse.d

    vault token create --policy concourse --period=720h > /etc/concourse.d/vault-token.log
    CONCOURSE_VAULT_CLIENT_TOKEN=`cat /etc/concourse.d/vault-token.log | awk '$1 == "token" { print $2}'`

    cat docker-compose.yml.template | \
      sed -e 's/%CONCOURSE_POSTGRES_PASSWORD/'${CONCOURSE_POSTGRES_PASSWORD}'/g' | \
      sed -e 's/%CONCOURSE_ADD_LOCAL_USER%/'${CONCOURSE_ADD_LOCAL_USER}'/g' | \
      sed -e 's/%CONCOURSE_MAIN_TEAM_LOCAL_USER%/'${CONCOURSE_MAIN_TEAM_LOCAL_USER}'/g' | \
      sed -e 's/%CONCOURSE_VAULT_CLIENT_TOKEN%/'${CONCOURSE_VAULT_CLIENT_TOKEN}'/g' > docker-compose.yml

    docker stop vagrant_concourse_1
    docker-compose up -d

    echo "export VAULT_ADDR=http://127.0.0.1:8200" >> ~vagrant/.bashrc
  SHELL

  config.vm.provision "shell", run: "always", inline: <<-SHELL
    i=1
    while ! nc -zv 127.0.0.1 8200; do
      i=$((i+1))
      echo "Waiting for Vault to listen on port 8200 (attempt $i)..."
      true
    done

    VAULT_ADDR=http://127.0.0.1:8200; export VAULT_ADDR

    i=1
    while true; do
      vault status
      if [ $? != 1 ]; then
        break
      fi
      i=$((i+1))
      echo "Waiting for Vault to report status (attempt $i)..."
      sleep 1
    done      
      
    /usr/local/bin/vault-unseal.sh
  SHELL
end
