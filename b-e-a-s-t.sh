#!/bin/sh
#
# Bulletproof Encrypted Arch Setup (Tool) aka B.E.A.S.T
#
#	Created by S.Werner 20.11.2018
#

# DEFAULT Values for Script Variables (Change to your needs)
DRIVE=/dev/sda
HOSTNAME=archlinux
_USERNAME=user
_USERPWD=qwer
_ROOTPWD=qwer
TIMEZONE=Europe/Berlin
LOCALE=de_DE
KEYMAP=de-latin1-nodeadkeys

# Change Keylayout on live System
loadkeys $KEYMAP

# Enable WIFI
wifi-menu

# Enable network time synchronization
timedatectl set-ntp true
                                                                                                                                                                                             
# Check it                                                                                                                                                                                   
timedatectl status                                                                                                                                                                           

# Select Drive
lsblk
echo -n " == Set drive: esp. "/dev/sda" "
read DRIVE
                      
# Wipe Drive Securely
echo -n " == Wipe Drive Securely? (Y/n): "
read SECURE_WIPE
if [ "${SECURE_WIPE:-y}" == "y" ]; then
	sgdisk --zap-all $DRIVE
	cryptsetup open --type plain $DRIVE container --key-file /dev/random
	dd if=/dev/zero of=/dev/mapper/container status=progress
	cryptsetup close container
fi

# Create partitions                                                                                                                                                                          
sgdisk --zap-all $DRIVE
sgdisk --clear \
	--new=1:0:+550MiB --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:+8GiB   --typecode=2:8200 --change-name=2:cryptswap \
    --new=3:0:0       --typecode=2:8200 --change-name=3:cryptsystem \
	$DRIVE

# Make filesystem for EFI
mkfs.fat -F32 /dev/sda1

# Create crypted System Container with /root and /home etc.
cryptsetup luksFormat ${DRIVE}3
cryptsetup open ${DRIVE}3 cryptsys
mkfs.btrfs -L ROOT /dev/mapper/cryptsys
mount /dev/mapper/cryptsys /mnt
btrfs sub cr /mnt/@
btrfs sub cr /mnt/@home
btrfs sub cr /mnt/@snapshots
btrfs sub set-default 257 /mnt
umount /mnt
mount /dev/mapper/cryptsys /mnt
mkdir /mnt/home
mount -o subvol=@home /dev/mapper/cryptsys /mnt/home

# Mount
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

# Check
lsblk

# Install system
pacstrap /mnt base base-devel grub-efi-x86_64 vim git efibootmgr dialog wpa_supplicant btrfs-progs bash-completion

# Generate fstab
genfstab -pU /mnt >> /mnt/etc/fstab

# Chroot into new installed system (make a block) need additional fixes
arch-chroot /mnt /bin/bash <<EOF

# Set timezone, hostname...
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc --utc
echo $HOSTNAME > /etc/hostname

# Configure locales
echo "$LOCALE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=$LOCALE.UTF-8 >> /etc/locale.conf

# Configure KEYMAP
echo KEYMAP=$KEYMAP > /etc/vconsole.conf

# Set root password
echo "root:${_ROOTPWD}" | chpasswd

# Change Binaries in /etc/mkinitcpio.conf
sed -i 's\^BINARIES=.*\BINARIES="/usr/bin/btrfs"\g' /etc/mkinitcpio.conf
# Change HOOKS in /etc/mkinitcpio.con
sed -i '/HOOKS="base udev autodetect modconf block filesystems keyboard fsck"/c\HOOKS="base udev autodetect modconf keyboard keymap block encrypt openswap resume filesystems"' /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Change grub config
sed -i 's/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g' /etc/default/grub
sed -i "s#^GRUB_CMDLINE_LINUX_DEFAULT=.*#GRUB_CMDLINE_LINUX_DEFAULT=\"resume=UUDI=$(blkid ${DRIVE}2 -s UUID -o value):cryptswap\"#g" /etc/default/grub
sed -i "s#^GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid ${DRIVE}3 -s UUID -o value):cryptsys\"#g" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Install grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux

# Create crypted Swap Container
cryptsetup luksFormat ${DRIVE}2
cryptsetup open ${DRIVE}2 cryptswap
mkswap /dev/mapper/cryptswap
dd bs=512 count=4 if=/dev/urandom of=/etc/keyfile-cryptswap
chmod 600 /etc/keyfile-cryptswap
cryptsetup luksAddKey ${DRIVE}2 /etc/keyfile-cryptswap
swapon /dev/mapper/cryptswap

# Same thing: open LVM without password prompt
dd bs=512 count=8 if=/dev/urandom of=/crypto_keyfile.bin
chmod 000 /crypto_keyfile.bin
cryptsetup luksAddKey ${DRIVE}3 /crypto_keyfile.bin
sed -i 's\^FILES=.*\FILES="/crypto_keyfile.bin"\g' /etc/mkinitcpio.conf
mkinitcpio -p linux
chmod 600 /boot/initramfs-linux*

# Enable Intel microcode CPU updates (if you use Intel processor, of course)
pacman -S intel-ucode
grub-mkconfig -o /boot/grub/grub.cfg

# Some additional security
chmod 700 /boot
chmod 700 /etc/iptables

# Create non-root user, set password
useradd -m -g users -G wheel,audio,video $_USERNAME
echo "${_USERNAME}:${_USERPWD}" | chpasswd

# Change sudoers file
sudo sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+ALL\)/\1/' /etc/sudoers
# and uncomment string %wheel ALL=(ALL) ALL

#localectl --no-convert set-x11-keymap de pc105 nodeadkeys
EOF
