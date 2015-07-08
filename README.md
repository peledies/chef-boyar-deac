#Chef Boyar Deac

This script is a provisioner for the Raspberry Pi. It can be used to perform the following tasks in an easy way.

* General setup tasks
* Configure wifi
* Install and configure Avahi
* Install and configure Chef

###Useage

Copy the setup.sh script onto a usb stick and plug it into your Raspberry Pi

**Create a mount point if it doesnt already exist**
```
$ sudo mkdir /media/usb
```

**Mount the USB drive to the mount point**
```
$ sudo mount /dev/sda1 /media/usb
```

**Navigate to the USB mount point**
```
$ cd /media/usb
```

**Run the setup script**
```
$ ./setup.sh
```

###Purging GUI files

**Before**
```
pi@raspberrypi ~ $ df -h /dev/root
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       2.9G  2.8G     0 100% /
```
**After**
```
pi@raspberrypi ~ $ df -h /dev/root
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       2.9G  2.0G  816M  71% /
```

**Storage Freed ≈ 800mb**