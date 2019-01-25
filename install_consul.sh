#!/usr/bin/env bash

echo 'This script will download, install, and setup Hashicorp Consul.  It assumes you will be making a 3 master cluster.'
echo
echo 'A few questions first though...'
echo
echo 'Which version should be installed? See: https://releases.hashicorp.com/consul/'
read -p 'Version? (ex: 1.4.1) ' CONSUL_VERSION
echo
echo 'What are the Server IPs?'
read -p 'Server 1: ' SERVER_IP1
read -p 'Server 2: ' SERVER_IP2
read -p 'Server 3: ' SERVER_IP3
echo
echo 'What is the IP of this Machine?'
read -p 'This Machine: ' THIS_MACHINE
echo
echo 'What is the Encryption Key that should be used?'
read -p 'Encryption Key: ' ENCRYPTION_KEY
echo
echo 'Thanks.  Proceeding with the install now.'
echo

echo
echo '*********** Downloading Consul ***********'
echo

curl --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

echo
echo '*********** Installing Consul ***********'
echo

echo 'Unzip the downloaded package and move the consul binary to /usr/local/bin/'
apt-get install unzip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
chown root:root consul
mv consul /usr/local/bin/
echo 'Check consul is available on the system path'
consul --version

echo 'Enable Auto-completion'
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

echo 'Create a unique, non-privileged system user to run Consul and create its data directory'
useradd --system --home /etc/consul.d --shell /bin/false consul
mkdir --parents /opt/consul
chown --recursive consul:consul /opt/consul

echo
echo '*********** Configuring Consul ***********'
echo

echo 'Setup systemd to auto-start consul on boot'
cat <<EOF >/etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


echo 'Create the general configuration file'
mkdir --parents /etc/consul.d
cat <<EOF >/etc/consul.d/consul.hcl
bind_addr = "${THIS_MACHINE}"
client_addr = "127.0.0.1 {THIS_MACHINE}"
datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "${ENCRYPTION_KEY}"
retry_join = ["${SERVER_IP1}", "${SERVER_IP2}", "${SERVER_IP3}"]
performance {
  raft_multiplier = 5
}
telemetry {
  dogstatsd_addr = "localhost:8125",
  disable_hostname = true
}
EOF
chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/consul.hcl

echo 'Create the server configuration file'
mkdir --parents /etc/consul.d
cat <<EOF >/etc/consul.d/server.hcl
server = true
bootstrap_expect = 3
ui = true
EOF
chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/server.hcl

echo
echo '*********** Starting Consul ***********'
echo

systemctl enable consul
systemctl start consul
systemctl status consul

echo 'Done!'
