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
