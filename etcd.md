### Etcd Cluster Setup

Etcd is a distributed key/value store that keeps all the data required for a kubernetes cluster.

For chromebox-kube, we will want to have all boxes running etcd so that we can maintain high-availablity.

#### Download and Install

Follow these steps on each box (for etcd 3.2.7)

* run `sudo su`
* run `mkdir /bin/etcd`
* run `export ETCD_VER=v3.2.7`
* run `export DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download`
* run `curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz`
* run `tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /bin/etcd/ --strip-components=1`
* run `/bin/etcd/etcd --version`
* run `ETCDCTL_API=3 /bin/etcd/etcdctl version`
* run `rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz`
* run `exit`

for more help, see: https://coreos.com/etcd/docs/latest/dl_build.html

#### Configuration

