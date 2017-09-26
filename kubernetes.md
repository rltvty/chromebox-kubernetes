## Highly Available Kubernetes Cluster

To make a Highly Available (HA) cluster, we need to create a distributed key/value store, run the kubeapi on each node, 
and setup master-elected scheduler and controller daemons.

### Install some stuff

#### Docker

1. Update the `apt` package index:
```
sudo apt-get update
```
2. Install packages to allow `apt` to use a repository over HTTPS:
```
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
```
3. Add Docker’s official GPG key:
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```
4. Use the following command to set up the stable repository:
```
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
5. Update the `apt` package index (to pull in the docker repository items)
```
sudo apt-get update
```
6. List available versions
```
apt-cache madison docker-ce
```
7. Install a version (17.06.02 in this case)
```
sudo apt-get install docker-ce=17.06.2~ce-0~ubuntu
```
8. Test the install
```
sudo docker run hello-world
```

#### Kubectl

1. Figure out the latest version
```
curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt
```
2. Download that release
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.7.6/bin/linux/amd64/kubectl
```
3. Make the kubectl binary executable.
```
chmod +x ./kubectl
```
4. Move the binary in to your PATH.
```
sudo mv ./kubectl /usr/local/bin/kubectl
```

#### kubelet and kubeadm
1. Become root
```
sudo -i
```
2. Install the things
```
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm
```

3. Exit root
```
exit
```

#### etcd
1. Become root
```
sudo -i
```
2. Install the things
```
export ETCD_VER=v3.2.7
export DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download && mkdir -p /tmp/etcd-download

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download --strip-components=1

mv /tmp/etcd-download/etcd* /usr/local/bin/

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download
```
3. Confirm installed versions
```
    etcd --version
    ETCDCTL_API=3 etcdctl version
```
4. Make the data directory
```
mkdir -p /var/etcd/data
```
5. Exit root
```
exit
```

### Setup etcd

#### Configure startup scripts

1. Make a copy of the example systemd service scripts from here: https://github.com/rltvty/chromebox-kubernetes/tree/master/etcd


2. Edit the `[Service]` section of each script
   * Set `ETCD_NAME` to the dns name of the specific box
   * Set `ETCD_LISTEN_PEER_URLS` to the ip of the specific box, keeping the existing port 
   * Set `ETCD_LISTEN_CLIENT_URLS` to the ip of the specific box, keeping the existing port and localhost config
   * Set `ETCD_ADVERTISE_CLIENT_URLS` to the ip of the specific box, keeping the existing port 
   * Set `ETCD_INITIAL_ADVERTISE_PEER_URLS` to the ip of the specific box, keeping the existing port
   * Set `ETCD_INITIAL_CLUSTER` to the host names and ips of all the boxes.  Will be the same on all boxes.
   * Set `ETCD_INITIAL_CLUSTER_TOKEN` to an unique name for your cluster.  Should be the same value on all boxes
3. Create a new file on each box and paste in the contents of the specific file for the box.
```
sudo vi /etc/systemd/system/etcd.service
```
4. Load the config, enable the service, start the service
```
sudo systemctl daemon-reload
sudo systemctl enable etcd.service
sudo systemctl restart etcd.service
```
5. Confirm etcd is runing
```
sudo systemctl status etcd
```
6. If not running, check logs
```
sudo journalctl -u etcd.service
```

