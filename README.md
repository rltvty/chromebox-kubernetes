# chromebox-kubernetes
How to create a Kubernetes cluster on a set of Chromeboxes

## Updating your chromebox to accept a custom OS

You need to put your chromebox into "developer mode" in order to install a custom OS. Note that the instructions below assume you want to completely replace chromeos with a custom OS.  If you want to dual-boot, do not follow these instructions.

WARNING: This will erase all user data on the device. 

With the device powered off:
* Insert a paperclip into the hole left of the SD card slot and press the recovery button

![Recovery Button](https://github.com/rltvty/chromebox-kubernetes/blob/master/images/Recoverybutton.png)

* Power on the device, then remove the paper clip
* When greeted with the recovery screen, press [CTRL-D] to enter developer mode
* Press the recovery button (with paperclip) to confirm.

After confirming, the device will reboot and wipe any existing user data - this will take ~5 minutes. Note that initially it will appear to not work.  Wait about a minute and stuff should start happening.  Afterwards, the ChromeBox will be in developer mode (vs verified boot mode), and the developer boot screen (shown below) will be displayed at each boot. 

![ChromeBox dev boot](https://github.com/rltvty/chromebox-kubernetes/blob/master/images/ChromeBox_dev_boot.jpg)

Note: The recovery button (and booting to recovery mode) are a function of the stock firmware. If you've flashed a custom firmware on your box (either as part of a standalone setup or otherwise), the recovery button has no function and the ChromeOS recovery mode doesn't exist. 

## Enable USB Booting

After in developer mode, the box will show the "scary" boot screen, and then continue to boot into Chromeos.  After it finshes, press `ctrl-alt-F2` to get a shell.

* login with `chronos` user.
* `sudo su` to get root
* `eanble_dev_usb_boot` to enable usb booting

## Installing the base OS 

### Ubuntu Server

Download the latest Ubuntu Server 64-bit LTS iso, from ubuntu.com.  

#### Create a bootable USB stick with the ISO from OS X terminal

General Instructions:
* insert the USB stick into your machine.
* run `diskutil list` to list the drives on your machine.  Note the USB drive number.  
* run `sudo umount \dev\disk?` where ? is the drive number.
* run `sudo dd if=/path/to/ubuntu.iso of=/dev/rdisk? bs=1m` 
* run `diskutil eject /dev/disk2` to eject the USB drive.  You can now remove the USB stick from your machine.

Here is the output from my machine:
```
$ diskutil list
/dev/disk0 (internal, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *1.0 TB     disk0
   1:                        EFI EFI                     209.7 MB   disk0s1
   2:          Apple_CoreStorage Mac HD                  999.7 GB   disk0s2
   3:                 Apple_Boot Recovery HD             650.0 MB   disk0s3

/dev/disk1 (internal, virtual):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                            Mac HD                 +999.3 GB   disk1
                                 Logical Volume on disk0s2
                                 REDACTED-EEEE-EEEE-EEEE-EEEEEEEEEEEE
                                 Unlocked Encrypted

/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                            CDROM                  *15.5 GB    disk2
```

My USB drive is: `/dev/disk2`

```
$ sudo umount /dev/disk2
Password:

$ sudo dd if=./Downloads/ubuntu-16.04.1-server-amd64.iso of=/dev/rdisk2 bs=1m
667+0 records in
667+0 records out
699400192 bytes transferred in 282.959217 secs (2471735 bytes/sec)

$ diskutil eject /dev/disk2
Disk /dev/disk2 ejected
```

### Reboot chrome box after enabling developer mode and inserting the USB install stick

On the developer warning screen, press `ctrl-U`

### Install ubuntu with minimal packages

### Setup SSH on chromebox

#### Create a SSH Key on your laptop

```
ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/epinzur/.ssh/id_rsa): id_rsa.home_kube
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in id_rsa.home_kube.
Your public key has been saved in id_rsa.home_kube.pub.
```

#### Install OpenSSL Server on chromebox

`sudo apt-get update`
`sudo apt-get install openssh-server`
`sudo service ssh start`

#### Copy SSH .pub keys onto a USB stick

plug stick into chromebox

run `lsblk` to find the usb stick

run `sudo mkdir -p /mnt/usb`
run `sudo mount /dev/sd?? /mnt/usb`

* run `mkdir ~/.ssh`
* run `chmod 0700 ~/.ssh`
* run `touch ~/.ssh/authorized_keys`
* run `cat /mnt/usb/id_rsa.something.pub >> ~/.ssh/authorized_keys`
* repeat above for additional ssh keys
* run `chmod 0600 ~/.ssh/authorized_keys`

#### Connect to chromebox via SSH from your laptop
* `ssh -i .ssh/id_rsa.something username@IP.Address`

## Install Kubernetes

See http://kubernetes.io/docs/getting-started-guides/kubeadm/

### Install

```
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
# apt-get update
# apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni
```

### Initialize Master

* `kubeadm init`

Output should look like this:

```
<master/tokens> generated token: "f0c861.753c505740ecde4c"
<master/pki> created keys and certificates in "/etc/kubernetes/pki"
<util/kubeconfig> created "/etc/kubernetes/kubelet.conf"
<util/kubeconfig> created "/etc/kubernetes/admin.conf"
<master/apiclient> created API client configuration
<master/apiclient> created API client, waiting for the control plane to become ready
<master/apiclient> all control plane components are healthy after 61.346626 seconds
<master/apiclient> waiting for at least one node to register and become ready
<master/apiclient> first node is ready after 4.506807 seconds
<master/discovery> created essential addon: kube-discovery
<master/addons> created essential addon: kube-proxy
<master/addons> created essential addon: kube-dns

Kubernetes master initialised successfully!

You can connect any number of nodes by running:

kubeadm join --token <token> <master-ip>
```

Make a record of the kubeadm join command that kubeadm init outputs. You will need this in a moment. The key included here is secret, keep it safe — anyone with this key can add authenticated nodes to your cluster.

By default, your cluster will not schedule pods on the master for security reasons. Run the following to allow pods to be able to run on the master.

* run `kubectl taint nodes --all dedicated-`

This will remove the “dedicated” taint from any nodes that have it, including the master node, meaning that the scheduler will then be able to schedule pods everywhere.

### Installing a pod network

You must install a pod network add-on so that your pods can communicate with each other.

`kubectl apply -f https://git.io/weave-kube`


### Check out your running pods

`kubectl get po --all-namespaces`

Outputs something like: 

```
NAMESPACE     NAME                              READY     STATUS    RESTARTS   AGE
kube-system   dummy-2088944543-e4rpp            1/1       Running   0          9m
kube-system   etcd-cb0                          1/1       Running   0          8m
kube-system   kube-apiserver-cb0                1/1       Running   2          9m
kube-system   kube-controller-manager-cb0       1/1       Running   0          8m
kube-system   kube-discovery-1150918428-ki3aj   1/1       Running   0          9m
kube-system   kube-dns-654381707-oxofr          3/3       Running   0          9m
kube-system   kube-proxy-qe2og                  1/1       Running   0          9m
kube-system   kube-scheduler-cb0                1/1       Running   0          8m
kube-system   weave-net-gzsis                   2/2       Running   0          2m
```





