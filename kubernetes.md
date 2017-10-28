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

* Install docker
   ```
   apt-get install -y docker.io
   ```

* Make sure that the cgroup driver used by kubelet is the same as the one used by Docker. 
   ```
   cat << EOF > /etc/docker/daemon.json
   {
       "exec-opts": ["native.cgroupdriver=systemd"]
   }
   EOF
   ```
* Restart docker
   ```
   systemctl restart docker
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
