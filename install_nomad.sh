#!/usr/bin/env bash

echo 'This script will download, install, and setup Hashicorp nomad.  It assumes you will be making a 3 master cluster.'
echo
echo 'A few questions first though...'
echo
echo 'Which version should be installed? See: https://releases.hashicorp.com/nomad/'
read -p 'Version? (ex: 0.8.7) ' NOMAD_VERSION
echo
echo 'What is the IP of this Machine?'
read -p 'This Machine: ' THIS_MACHINE
echo
echo 'Thanks.  Proceeding with the install now.'
echo

echo
echo '*********** Downloading nomad ***********'
echo

curl --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip

echo
echo '*********** Installing nomad ***********'
echo

echo 'Unzip the downloaded package and move the nomad binary to /usr/local/bin/'
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
chown root:root nomad
mv nomad /usr/local/bin/
echo 'Check nomad is available on the system path'
nomad --version

echo 'Enable Auto-completion'
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad

echo 'Create a unique, non-privileged system user to run nomad and create its data directory'
useradd --system --home /etc/nomad.d --shell /bin/false nomad
mkdir --parents /opt/nomad
chown --recursive nomad:nomad /opt/nomad

echo
echo '*********** Configuring nomad ***********'
echo

echo 'Setup systemd to auto-start nomad on boot'
cat <<EOF >/etc/systemd/system/nomad.service
[Unit]
Description="HashiCorp Nomad - An application and service scheduler"
Documentation=https://www.nomad.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/nomad.d/nomad.hcl

[Service]
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


echo 'Create the general configuration file'
mkdir --parents /etc/nomad.d
cat <<EOF >/etc/nomad.d/nomad.hcl
bind_addr = "${THIS_MACHINE}"
datacenter = "dc1"
data_dir = "/opt/nomad"
telemetry {
  datadog_address = "localhost:8125"
}
consul {
  address = "127.0.0.1:8500"
}
EOF
chown --recursive nomad:nomad /etc/nomad.d
chmod 640 /etc/nomad.d/nomad.hcl

echo 'Create the server configuration file'
mkdir --parents /etc/nomad.d
cat <<EOF >/etc/nomad.d/server.hcl
server {
  enabled = true
  bootstrap_expect = 3
}
EOF
chown --recursive nomad:nomad /etc/nomad.d
chmod 640 /etc/nomad.d/server.hcl

echo
echo '*********** Starting nomad ***********'
echo

systemctl enable nomad
systemctl start nomad
systemctl status nomad

echo 'Done!'
