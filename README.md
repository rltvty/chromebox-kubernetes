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

Follow the install process.  I'll note options you should choose below, for when it is less clear what to do.  These are the steps using Ubuntu Server 18.04.1 LTS.  They may be different on other versions

* Choose your language (English for me), and default keyboard setup
* Choose *Install Ubuntu*
* Use default network interface
* No proxy address
* Use standard ubuntu mirror
* Filesystem setup
  * Use An Entire Disk
    * Choose default
  * Done
  * Continue
* Profile Setup
   * Your Name
   * Server name: should be differeont on each box... I used cb0, cb1, and cb2
   * Username & Password: I recommend using the same for all 3 boxes
   * Import SSH Identity: from Github
     * Put in github username
* Confirm github SSH keys
* Featured Server Snaps, choose:
  * docker
* Reboot

### After initial boot

* login using user/pass created during install
* verify all boxes have different mac addresses:
  * run `sudo ifconfig`
    * compare the hardware address for the Ethernet device on each box
    * For me was device `enp1s0`, and 2 of my 3 boxes had the same hardware address
* if needed, adjust mac addreses:
  * run `sudo apt install ifupdown`
  * edit `/etc/network/interfaces` => run `sudo vi /etc/network/interfaces`
  * configure the ethernet adapter to specify a unique hardware address on each box
     * example completed config for `enp1s0`: 
     ```
      auto enp1s0
      iface enp1s0 inet dhcp
          hwaddress aa:bb:cc:dd:ee:01
     ```
  * restart the box to get the new network configuration
    * run `sudo shutdown -r now`
      
### Installing Consul

Based on the [Consul Deployment Guide](https://learn.hashicorp.com/consul/advanced/day-1-operations/deployment-guide)

* copy the `install_consul.sh` script to each machine and run it with sudo.  
  * `sudo bash install_consul.sh`
  * Follow the prompts.

### Installing Nomad

Based on the [Nomad Deployment Guide](https://www.nomadproject.io/guides/operations/deployment-guide.html)

* copy the `install_nomad.sh` script to each machine and run it with sudo.  
  * `sudo bash install_nomad.sh`
  * Follow the prompts.
  
### Using Nomad

Be sure to set the nomad address environment variable before using any nomad commands:
```
export NOMAD_ADDR=http://10.10.10.???:4646
```
