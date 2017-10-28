## Highly Available Kubernetes Cluster

To make a Highly Available (HA) cluster, we need to create a distributed key/value store, run the kubeapi on each node, 
and setup master-elected scheduler and controller daemons.

### Install some stuff

#### Pre-requisites

On every node do the following:

* get root
   ```
   sudo su
   ```
* disable swap
   ```
   swapoff -a
   ```

* Set `/proc/sys/net/bridge/bridge-nf-call-iptables` to `1` to pass bridged IPv4 traffic to iptables’ chains. This is a requirement for CNI plugins to work, for more information please see: [here](https://kubernetes.io/docs/concepts/cluster-administration/network-plugins/#network-plugin-requirements).
   ```
   sysctl net.bridge.bridge-nf-call-iptables=1
   ```

* Verify the MAC address and product_uuid are unique
   ```
   ifconfig -a
   ```
   Ensure the ip address and mac address for the primary network interface on each node is unique.  
     * `enp1s01` is the primary network interface on my nodes.
     
* Update your libraries
  ```
  apt-get update
  apt-get upgrade
  apt autoremove
  ```

#### Docker

On every node do the following:

* Install packages to allow apt to use a repository over HTTPS:
   ```
   apt-get install \
       apt-transport-https \
       ca-certificates \
       curl \
       software-properties-common
   ```

* Add Docker’s official GPG key:
   ```
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   ```

* Verify that you now have the key with the fingerprint
   ```
   apt-key fingerprint 0EBFCD88
   ```
  * should get:
     ```
     pub   4096R/0EBFCD88 2017-02-22
         Key fingerprint = 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
     uid                  Docker Release (CE deb) <docker@docker.com>
     sub   4096R/F273FCD8 2017-02-22
     ```

* Use the following command to set up the stable repository
   ```
   add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
   ```

* Update the apt package index:
   ```
   apt-get update
   ```

* Look at available versions:
   ```
   apt-cache madison docker-ce
   ```

* Install a version (use the same on every node):
   ```
   apt-get install docker-ce=17.03.2~ce-0~ubuntu-xenial
   ```

#### Kubectl, Kubeadm, Kubelet

On every node do the following:

* Install the things
   ```
   apt-get update && apt-get install -y apt-transport-https
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
   cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
   deb http://apt.kubernetes.io/ kubernetes-xenial main
   EOF
   apt-get update
   apt-get install -y kubelet kubeadm kubectl
   ```

#### etcd

On every node do the following:

* Install the things
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
* Confirm installed versions
   ```
   etcd --version
   ```
* Make the data directory
   ```
   mkdir -p /var/etcd/data
   ```

### Setup etcd

#### Configure startup scripts

On every node do the following:

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

#### Verify Etcd

From any node:

```
etcdctl cluster-health
```

### Setup kubernetes

#### Configure a single master node

On one node:

* Create a master config file, specifiying your existing etcd cluster:
   ```
   vi /etc/kubernetes/master.yaml
   ```
   * Add this contents, updated with your machine ips, hostnames, load-balancer ip & hostname:
      ```
      apiVersion: kubeadm.k8s.io/v1alpha1
      kind: MasterConfiguration
      etcd:
        endpoints:
        - http://192.168.1.10:2379
        - http://192.168.1.11:2379
        - http://192.168.1.12:2379
      networking:
        podSubnet: 10.244.0.0/16
      apiServerCertSANs:
      - cb0
      - cb1
      - cb2
      - kube
      - 192.168.1.10
      - 192.168.1.11
      - 192.168.1.12
      - 192.168.1.80
      ```

* Run kubeadm with the config file to create a bunch of stuff and get your master node going
   ```
   kubeadm init --config /etc/kubernetes/master.yaml
   ```
   * Make sure to save the `kubeadm join` command output.  It should look something like this:
      ```
      kubeadm join --token 12345f.abcdef12345678 192.168.1.10:6443 --discovery-token-ca-cert-hash sha256:0123456789abcdef...
      ```

* Exit root
   ```
   exit
   ```
   
* Setup kubectl access from your normal user
   ```
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```
   
* Add Weave as the pod network
   ```
   export kubever=$(kubectl version | base64 | tr -d '\n')
   kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
   ```

* Remove the 'master' taint from the node, so that it can run containers
   ```
   kubectl taint nodes --all node-role.kubernetes.io/master-
   ```
* Create tar of config files for next step
  * goto home directory
     ```
     cd ~
     ```
  * tar up files
     ```
     sudo tar -zcvf kube_master_configs.tar.gz /etc/kubernetes/*
     ```
   
#### Create the High Availability Cluster

On the remaining nodes, with root:

* goto home folder
   ```
   cd ~
   ```
   
* use scp to copy config tar to node (make sure to update with your user and master node ip)
   ```
   scp user@192.168.1.10:kube_master_configs.tar.gz ./ 
   ```

* make initial config folder
   ```
   mkdir /etc/kubernetes
   ```
* extract the configs
   ```
   tar -xf kube_master_configs.tar.gz -C /
   ```


