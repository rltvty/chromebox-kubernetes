# chromebox-kubernetes
How to create a Kubernetes cluster on a set of Chromeboxes

## Updating your chromebox to accept a custom OS

### Open the chromebox and remove the firmware write protect screw

![Firmware Write Protext](https://github.com/rltvty/chromebox-kubernetes/blob/master/images/inside-chromebox.jpg)

### Switching to developer mode

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

### Enable USB Booting

After in developer mode, the box will show the "scary" boot screen, and then continue to boot into Chromeos.  After it finshes, press `ctrl-alt-F2` to get a shell.

* login with `chronos` user.
* `sudo su` to get root
* `chromeos-firmwareupdate –-mode=todev`
* `crossystem dev_boot_usb=1`
* `crossystem dev_boot_legacy=1`
* `exit` to get out of root

### Install SeaBIOS 

Reference: https://johnlewis.ie/custom-chromebook-firmware/rom-download/

From the chronos promt:

* `cd; rm -f flash_chromebook_rom.sh; curl -O https://johnlewis.ie/flash_chromebook_rom.sh; sudo -E bash flash_chromebook_rom.sh`
* When prompted Choose the *FULL ROM* option.  It was #5 for me.
* When prompted type `If this bricks my panther, on my head be it!`

It may appear like nothing is happening.  Just wait until it finishes. Takes about 5 minutes.

Don't worry that the script was written for chromeBOOK and we are using a chromeBOX

## Installing the base OS 

We will be using ubuntu server as the base OS.

Download the latest Ubuntu Server 64-bit LTS iso, from ubuntu.com.  

### Create a bootable USB stick with the ISO from OS X terminal

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

### Install the OS

#### Initial install

* make sure your chromebox is in developer mode, has seaBIOS installed, etc... (see above)
* put the USB Install stick into the chromebos
* start (or reboot) the chromebox
* press ESC at the boot menu, then select the USB drive.  
* * There may be 2 or more USB options.  If one doesn't work, restart the box and try another.
* * If it still doesn't boot, try making a bootable USB stick with another brand/type USB Stick.  (I've had no success using cheap sticks that companies give out as promotions, but every stick I've bought myself has worked fine.)

#### Install ubuntu with minimal packages

Follow the install process.  I'll note options you should choose below, for when it is less clear what to do.  These are the steps using Ubuntu Server 16.04.3 LTS.  They may be different on other versions

* Choose *Install Ubuntu Server*
* Hostname selection: Make sure each box is different... I used cb0, cb1, and cb2
* Username & Password: Use the same for all 3 boxes
* Don't bother encrypting your home directory
* Unmount partitions that are in use? - YES
* Partitioning method: Manual, working on disk: SCSI1 (0,0,0) (sda)
  * Note that we will create a single partition that covers the full disk.  There will be no swap partition since this is no longer usable with kubernetes and therefore will just take up space that can be used elsewhere.
  * Delete Swap partition
  * Delete Primary partition
  * Create new partition in the free space
    * 16 GB / Primary / Mount point: `/` / Bootable - On / Done setting up the partition
* Finish partitioning and write chagnes to disk - YES
* On no-swap-space confirmation page, say <No> to continue without setting up swap space.
* Confirm <Yes> to write changes to disk.
* HTTP proxy information: (blank)
* How do you want to manage upgrades on this system? - Install security updates automatically

* Choose software to install:
* * unselect `standard system utilities` (takes about 600 MB that can be used for pods instead)
* * select openssh-server

* Install the GRUB boot loader to the master boot record? - YES
* Device for boot laoder installation: /dev/sda

### After initial boot

* login using user/pass created during install
* verify all boxes have different mac addresses:
  * run `sudo ifconfig`
    * compare the hardware address for the Ethernet device on each box
    * For me was device `enp1s0`, and 2 of my 3 boxes had the same hardware address
* if needed, adjust mac addreses:
  * edit `/etc/network/interfaces` => run `sudo vi /etc/network/interfaces`
  * add a line to the ethernet adapter section to specify a unique hardware address on each box
     * example completed config for `enp1s0`: 
     ```
      auto enp1s0
      iface enp1s0 inet dhcp
          hwaddress aa:bb:cc:dd:ee:01
     ```
  * restart the box to get the new network configuration
    * run `sudo shutdown -r now`
      
### Setup SSH on chromebox

#### Create a SSH Key on your laptop

```
ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/user_name/.ssh/id_rsa): id_rsa.home_kube
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in id_rsa.home_kube.
Your public key has been saved in id_rsa.home_kube.pub.
```

#### Copy SSH .pub keys onto a USB stick

plug stick into chromebox

* run `lsblk` to find the usb stick

* run `sudo mkdir -p /mnt/usb`
* run `sudo mount /dev/sd?? /mnt/usb`

* run `mkdir ~/.ssh`
* run `chmod 0700 ~/.ssh`
* run `touch ~/.ssh/authorized_keys`
* run `cat /mnt/usb/id_rsa.something.pub >> ~/.ssh/authorized_keys`
* repeat above for additional ssh keys
* run `chmod 0600 ~/.ssh/authorized_keys`

* run `sudo umount /mnt/usb`

#### Connect to chromebox via SSH from your laptop
* `ssh -i .ssh/id_rsa.something username@IP.Address`

## Create the intial Kubernetes Master

Following the steps below, you can create a Kubernetes Master on a single chromebox.  After the initial master is setup, we will transition to a High Availablity (HA) cluster by copying configuration to the other boxes.

Refrence http://kubernetes.io/docs/getting-started-guides/kubeadm/ for more info.

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

### Install Weave Scope and Kubernetes Dashboard

* `kubectl apply -f 'https://cloud.weave.works/launch/k8s/weavescope.yaml'`
* `kubectl apply -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml`







