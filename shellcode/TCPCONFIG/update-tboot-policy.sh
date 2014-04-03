#!/bin/bash
#
# This script will create the Launch Control Policy (lcp) and tboot policy
# for a Measured Launch Environment (mle) and write the policy to the NVRAM on
# the Trusted Platform Module (tpm) on the mobo.


if [ $UID -ne 0 ]; then
    echo "This can only be executed as root.  Aborting."
    exit 1
fi

# TPM password - MUST BE 20 CHARACTERS!
PASSWORD="Eigentuemer Passwort"

# Clean up the files after we're done?
CLEAN_UP=false

cd /root

# Clean up the files before we start!  vl.pol is simply appended to, not.
# written over - might as well clean up everything else, too.
rm -f vl.pol

# g. Generate the tboot policy to control expected kernel and initrd:
tb_polgen --create --type nonfatal vl.pol

# which kernel is the default kernel
m=`grep default /boot/grub/grub.conf  | awk -F= '{print $2}'`

# add 1 'cause we're zero based counting
let n=m+1

# set the boot CMD_LINE
# tboot and grub v1 don't play well together (e.g., an extra space between.
# cli options can cause tboot to fail), we need to use sed instead of awk.
# Apparently this is not an issue with grub2
#CMD_LINE="`grep vmlinuz-[23] /boot/grub/grub.conf | head -n${n} | tail -n1 | awk '{for (i=1; i<=NF; i++) $i = $(i+2); NF; print}'`"

CMD_LINE="`grep vmlinuz-[23] /boot/grub/grub.conf | head -n${n} | tail -n1 | sed -e 's/^[ \t]*//' | cut -d\  -f3-`"

# set the kernel image
KERNEL_IMG="`grep vmlinuz-[23] /boot/grub/grub.conf | head -n${n} | tail -n1 | awk '{print $2}'`"

# set the initramfs image
INITRAMFS_IMG="`grep initramfs-[23] /boot/grub/grub.conf | head -n${n} | tail -n1 | awk '{print $2}'`"

# finally, create the policy for the images
tb_polgen --add --num 0 --pcr none --hash image --cmdline "$CMD_LINE" --image /boot/${KERNEL_IMG} vl.pol
tb_polgen --add --num 1 --pcr 19 --hash image --cmdline "" --image /boot/${INITRAMFS_IMG} vl.pol

# l. Write the tboot policy (from vl.pol) into the NV index:
lcp_writepol -i 0x20000001 -f vl.pol -p "$PASSWORD"

if [ $CLEAN_UP = "true" ]; then
    rm -f vl.pol
fi
