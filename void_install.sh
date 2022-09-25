#!/bin/sh
# == MY VOID SETUP INSTALLER By ROMACHAD == #
#INSERT VARIABLES HERE!
#######################
BTRFS_OPTS="rw,noatime,ssd,compress=zstd,space_cache,commit=120"
REPO=https://repo-default.voidlinux.org/current
#If installing musl change the value below to x86_64-musl
ARCH=x86_64
locale="LANG=en_US.UTF-8"
libc_locale="en_US.UTF-8 UTF-8"
Groups="wheel,audio,video,kvm"
Keyboard_layout=br-abnt2
Timezone=America/Sao_Paulo





#######################
#The lines below until part2 begins will be deleted for part2 execution.
#part1
printf '\033c'
echo "Welcome to romachad moded void installer script"
#loadkeys br-abnt2
# timedatectl set-ntp true
lsblk
echo "Choose the drive to install the VOID.\n\nChoose GPT table and create 3 partitions:"
echo "1-> EFI patition with size of at lease +200M\n2-> Boot partition of at least +800M (this one as Linux filesystem)\n3-> The remainder as Linux filesystem"
echo "\nChoose disk:"
read drive
fdisk /dev/$drive
t_part=$(lsblk | grep $drive|grep -v "^$drive"|wc -l)
[ $t_part -ne 3 ] && echo "Its necessary 3 partitions! The $drive has only $t_part!\nStart the script again and fix this in the fdisk!" && exit 1;

efi_part=$(fdisk -l /dev/$drive | grep "${drive}1"|grep EFI|wc -l)
[ $efi_part -ne 1 ] && echo "There should be ONE EFI partition it was found: $efi_part!\nStart the script again and fix this in the fdisk!" && exit 1;

#Create the file systems!
mkfs.vfat -nBOOT -F32 /dev/${drive}1
mkfs.ext2 -L grub /dev/${drive}2

echo "Creating LUKS-encrypted root partition."
cryptsetup luksFormat --type=luks -s=512 /dev/${drive}3
echo "Type the password again to open the partition:"
cryptsetup open /dev/${drive}3 cryptroot
mkfs.btrfs -L void /dev/mapper/cryptroot
echo "Partitions created"
#Partitions created.

#Mounting the partitions
mount -o $BTRFS_OPTS /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
umount /mnt

mount -o $BTRFS_OPTS,subvol=@ /dev/mapper/cryptroot /mnt

mkdir /mnt/home
mount -o $BTRFS_OPTS,subvol=@home /dev/mapper/cryptroot /mnt/home

mkdir /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots

#Mounting nested partitions which wont have a snapshot taken:
mkdir -p /mnt/var/cache
btrfs subvolume create /mnt/var/cache/xbps
btrfs subvolume create /mnt/var/tmp
btrfs subvolume create /mnt/srv

mkdir /mnt/efi
mount -o rw,noatime /dev/${drive}1 /mnt/efi

mkdir /mnt/boot
mount -o rw,noatime /dev/${drive}2 /mnt/boot
#End of mount

#Base installation, here you can change to add whatever packages you prefer after the grub.
$(XBPS_ARCH=$ARCH)
xbps-install -Sy -R "$REPO" -r /mnt base-system btrfs-progs cryptsetup grub-x86_64-efi #vim neovim htop
#End of Base install

#Prep for chroot
for dir in dev proc sys run; do mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
cp /etc/resolv.conf /mnt/etc/
sed '20,/^#part2$/d' `basename $0` > /mnt/void_install2.sh
echo $drive > /mnt/drive
chmod 744 /mnt/void_install2.sh
chroot /mnt/ ./void_install2.sh
#End of chroot
rm -f /mnt/void_install2.sh
exit

#part2
printf '\033c'
drive=$(cat drive)
#echo "Nothing here yet! =(\n\nFTS!"
echo "Type the hostname:"
read hname
echo $hname > /etc/hostname
echo "\nType the user login:"
read usrlogin
useradd -m -G $Groups -s /bin/bash $usrlogin
echo "\nChoose the password for $usrlogin:"
passwd $usrlogin

#Timezone and key maps ajustment
cp /etc/rc.conf /etc/rc.conf.orig
cat /etc/rc.conf |sed "s/^#KEYMAP=\"us\"/KEYMAP=$Keyboard_layout" > /etc/rc.conf.new
mv /etc/rc.conf.new /etc/rc.conf
cat /etc/rc.conf |sed "s/^#TIMEZONE=\"Europe\/Madrid\"/TIMEZONE=$Timezone" > /etc/rc.conf.new
mv /etc/rc.conf.new /etc/rc.conf

echo "$locale" > /etc/locale.conf
echo "$libc_locale" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

echo "Set the password of root:"
passwd

mv /etc/fstab /etc/fstab_install.orig
UEFI_UUID=$(blkid -s UUID -o value /dev/${drive}1)
GRUB_UUID=$(blkid -s UUID -o value /dev/${drive}2)
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)
cat /etc/fstab_install.orig |grep "^#" > /etc/fstab
echo "UUID=$ROOT_UUID	/	btrfs	$BTRFS_OPTS,subvol=@	0	1" >> /etc/fstab
echo "UUID=$UEFI_UUID	/efi	vfat	defaults,noatime	0	2" >> /etc/fstab
echo "UUID=$GRUB_UUID	/boot	ext2	defaults,noatime	0	2" >> /etc/fstab
echo "UUID=$ROOT_UUID	/home	btrfs	$BTRFS_OPTS,subvol=@home	0	2" >> /etc/fstab
echo "UUID=$ROOT_UUID	/.snapshots	btrfs	$BTRFS_OPTS,subvol=@snapshots	0	2" >> /etc/fstab
cat /etc/fstab_install.orig |grep -v "^#" >> /etc/fstab

echo hostonly=yes >> /etc/dracut.conf

#Adding the non free repo and installing further packages:
xbps-install -Syu void-repo-nonfree
#ADD HERE check for pkgs list to be installed!

#Add services on the startup!
#WARNING: This is not and ideal way to get the interface name, however for me I know that there is only one interface.
Interface=$(ip link show|grep "^.:"|grep -v "lo"|awk '{print $2}'|sed 's/://')
cp -R /etc/sv/dhcpcd-eth0 /etc/sv/dhcpcd-$Interface
sed -i "s/eth0/$Interface/" /etc/sv/dhcpcd-$Interface/run
ln -s /etc/sv/dhcpcd-$Interface /var/service/

#SSH server
ln -s /etc/sv/sshd /var/service

#iptables:
ln -s /etc/sv/ip6tables /var/service
ln -s /etc/sv/iptables /var/service
cp /etc/iptables/simple_firewall.rules /etc/iptables/iptables.rules
cp /etc/iptables/simple_firewall.rules /etc/iptables/ip6tables.rules
ip6tables -P OUTPUT DROP
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -t mangle -P INPUT DROP
ip6tables -t mangle -P PREROUTING DROP
ip6tables -t mangle -P FORWARD DROP
ip6tables -t mangle -P OUTPUT DROP
ip6tables -t mangle -P POSTROUTING DROP
ip6tables -t raw -P PREROUTING DROP
ip6tables -t raw -P OUTPUT DROP
ip6tables-save > /etc/iptables/ip6tables.rules

#Chronyd (If not installing comment the line below)
ln -s /etc/sv/chronyd /var/service

#GRUB Install
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id="Void Linux"
xbps-reconfigure -fa

#Clean up
rm -f drive
#Commented the exit to validate the execution so far
exit
