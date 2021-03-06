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
rm -f mle_hash mle.elt pcrs pconf.elt list_unsig.lst privkey.pem pubkey.pem list_sig.lst list.pol list.data vl.pol

if [ ! -e /boot/tboot.gz ]; then.
    echo "/boot/tboot.gz does not exist - did you install tboot?"
    echo "(yum -y install tboot)"
    exit 1
fi

# a. Create hash for tboot.gz and store it in the mle_hash file:
lcp_mlehash -c "logging=vga,serial,memory" /boot/tboot.gz > mle_hash

# b. Create the policy element for tboot (mle), take the input hash from mle_hash, and output to mle_elt:
lcp_crtpolelt --create --type mle --ctrl 0x00 --minver 17 --out mle.elt mle_hash

# c. Create the policy element for the platform configuration (pconf).
cat `find /sys/devices -name pcrs` | grep -e PCR-0[01] > pcrs
lcp_crtpolelt --create --type pconf --out pconf.elt pcrs

# d. Create the unsigned policy list file list_unsig.lst, using mle_elt and pconf_elt
lcp_crtpollist --create --out list_unsig.lst mle.elt pconf.elt

# e. Create an RSA key pair, and use it to sign the policy list, list_sig.lst, in both the input and the output files:
openssl genrsa -out privkey.pem 2048 &> /dev/null
openssl rsa -pubout -in privkey.pem -out pubkey.pem &> /dev/null
cp list_unsig.lst list_sig.lst
lcp_crtpollist --sign --pub pubkey.pem --priv privkey.pem --out list_sig.lst

# f. Create the final LCP policy blobs from list_sig.lst, and generate the list_pol and list_data files:
lcp_crtpol2 --create --type list --pol list.pol --data list.data list_sig.lst

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

# h. Create the TPM NV index for recording boot errors:
tpmnv_defindex -i 0x20000002 -s 8 -pv 0 -rl 0x07 -wl 0x07 -p "$PASSWORD"

# i. Create the TPM NV index for the owner-created LCP policy:
tpmnv_defindex -i owner -p "$PASSWORD"

# j. Create the TPM NV index for the tboot policy:
tpmnv_defindex -i 0x20000001 -s 256 -pv 0x02 -p "$PASSWORD"

# k. Write the LCP policy (from list.pol) into the owners NV index
lcp_writepol -i owner -f list.pol -p "$PASSWORD"

# l. Write the tboot policy (from vl.pol) into the NV index:
lcp_writepol -i 0x20000001 -f vl.pol -p "$PASSWORD"

# m. Copy list data to /boot/ for use by GRUB:
cp list.data /boot/

if [ $CLEAN_UP = "true" ]; then
    rm -f mle_hash mle.elt pcrs pconf.elt list_unsig.lst privkey.pem pubkey.pem list_sig.lst list.pol list.data vl.pol
fi
