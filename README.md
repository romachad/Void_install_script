# Void install script with LUKS-encrypted btrfs
This script was created based on the instructions of gbrlsnchs ([Link Here](https://gist.github.com/gbrlsnchs/9c9dc55cd0beb26e141ee3ea59f26e21)), the script of Bugswriter [Arch script](https://github.com/bugswriter/arch-linux-magic) and of course the Void Linux Documentation.

If you want to download the script for installing in the Void Linux execute the following steps below (provided that you have internet connection):

```
xbps-install -Sy -u xbps
xbps-install -Sy -R https://repo-default.voidlinux.org/current wget
wget https://raw.githubusercontent.com/romachad/Void_install_script/main/void_install.sh
chmod 744 void_install.sh
./void_install.sh
```


## WARNING: THIS IS STILL A WORK IN PROGRESS!
Currently the script only does the base install with UEFI and the LUKS encryption with btrfs. It's still pretty bare bones.
