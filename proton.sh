#!/bin/bash
#
# @file
# @brief Tools for extracting and working with ISO for CD or USB Boot
#
# @see http://edoceo.com/liber/gentoo-live-usb
# @see http://edoceo.com/liber/ubuntu-live-usb
# @see http://element.edoceo.com/proton
#
# @see https://help.ubuntu.com/community/LiveCDCustomization
# @see https://bugs.launchpad.net/ubuntu/+source/upstart/+bug/430224
#
# @see http://blog.piotrj.org/2009/03/mounting-raw-kvmqemu-image.html
# @see http://en.gentoo-wiki.com/wiki/KVM
# @see http://www.abclinuxu.cz/clanky/system/livecd-1-uvod-isolinux
# @see http://syslinux.zytor.com/wiki/index.php/SYSLINUX
#
# @see http://tldp.org/LDP/abs/html/loops1.html

# Initialize Variables

# Colors and reset Screen
# CLEAR="c"
N="\033[0;39m" # Reset Terminal Defaults
R="\033[1;31m" # R: Failure or error message
G="\033[1;32m" # G: Commands
Y="\033[1;33m" # Y: Options
B="\033[1;34m" # B: Paths
# MAGENTA: Found devices or drivers
# MAGENTA="[1;35m"
# CYAN: Questions
# CYAN="[1;36m"
W="\033[1;37m" # white
# X="\033[1;38m" # white

# Path of my Script
proton_path=$(dirname $(readlink -f $0))
# Path to Work in (Current Directory)
proton_work=$(pwd)

# Default Options
# Optional Device to Burn to after iso-pack
opt_burn=
opt_name="Proton"
opt_file=$(echo "$opt_name"|tr [:upper:] [:lower:])
opt_squash=1
opt_hack="no"
opt_tiny="no"

live_boot=$proton_work/_isoboot
live_name=proton
live_over=$proton_work/_envover

# sysroot holds our build environment
sysdisk=$proton_work/sysdisk.raw
sysroot=$proton_work/sysdisk/
# envroot holds our build->staging area
envdisk=$proton_work/envdisk.raw
envfile=$proton_work/$live_name.sfs
envroot=$proton_work/envroot/
# where the files live before packing into ISO
isofile="$proton_work/proton.iso"     # Packed ISO
isoloop="$proton_work/iso-loop"       # Source ISO Mount Loop
isowork="$proton_work/iso-work"       # ISO Working Temp Directory
# where the KVM image is mounted too for cloning
# the name of the file that is the kvm boot disk
kvmdisk="$proton_work/kvmdisk.raw"    # KVM Image File
kvmroot="$proton_work/kvmroot/"       # KVM Mount Point => loop?
# Should only be $ramroot
# ramfile=$isoroot/sysroot/proton.igz
# ramroot=$proton_work/ramroot/
sfsloop="$proton_work/sfs-loop"       # SquashFS Mount Point
# sysfile=$proton_work/sysroot.tgz
syswork="$proton_work/sys-work"       # Working Directory for Chroot
# where the usb gets mounted and built
# usbroot=$proton_work/usbroot/

# kvm_disk=
# kvm_name=live.vm
# kvm_monx=
# kvm_tapx=
# kvm_vncx=
# usb_part=


set -o errexit
set -o noclobber
set -o nounset

#
# Echo Shortcut
#
function e() { echo -e "$@"; }

#
# Help
#
function proton_help()
{
    e "Proton Live CD/DVD Tools - http://element.edoceo.com/proton"
    e
    e " ${W}$0 ${Y}[options] ${G}command <${Y}params${N}> ${N}[${Y}[options] ${G}command${N}]"
    e
    if [[ -n "${1-}" ]]; then
        e "  ${R}$1${N}\n"
        exit
    fi
    e "Options:"
    e ""
    e "  --name=\w+    A name for the Work"
    e "  --iso=<file>  The ISO File to open,boot,pack"
    e "  --usb=<dev|part|path> the USB device, partition or mount point"
    # e "  --fake            only print what would be done, don't do it"
    # e "  --loud            verbose"
    # e "  --only=#          only run this job"
    # e "  --sort=name|size  sort by one of those two things"
    e
    e "Commands:"
    e "  ${G}cfg-dump${N} - show configuration"
    e "  ${G}iso-open${N} - open the specified ISO"
    e "  --iso=${B}file.iso"
    e "  ${G}img-root${N} - enter the bootable FS via chroot"
    e "  ${G}img-boot${N} - boot ${B}$sysdisk${N} via KVM"
    # e "  ${G}img-pack${N} - pack ${B}$sysdisk${N} image to ${B}$envroot${N}"
    # e "     ${Y}+tiny${N} - remove extra stuff from the environtment"
    e "  ${G}img-pack${N} - pack ${B}${syswork}${N} > SquashFS"
    e "  ${G}iso-pack${N} - pack ${B}${isowork}${N} > ${B}${isofile}${N}"
    e "      ${Y}+burn${N}=${B}/dev/sr0${N} burn to this device"
    e "  ${G}iso-boot${N} - boot the recently created ISO"
    e "  isoboot <${B}file.iso${N}>"
    e "  ${G}usb-pack${N} - pack system onto usb device"
    e "      <${B}/dev/sdX${N} | ${B}/dev/sdX#${N} | ${B}/mnt/usb${N}>"
    e "      ${B}/dev/sdX${N}  pack onto entire USB stick"
    e "      ${B}/dev/sdX#${N} pack onto this partition only (usually 1)"
    e "      ${B}/mnt/usb${N}  pack onto mounted partition"
    e
    # echo "  ${G}env-boot${N} - copies ${B}$envroot${N} to ${B}$kvmdisk${N} and runs with kvm";
    # echo "    Make a new $(basename $kvmdisk) and boot it";
    # echo "    ${B}# ${G}xxx${N}";
    # echo
    # echo "    Use existing KVM disk file\n";
    # echo "    ${B}# ${G} ${Y}+disk=kvmdisk.raw${N}\n";
    e "Examples:"
    e " ${W}$0${N} --iso=source.iso iso-open"
    e " ${W}$0${N} img-root"
    e " ${W}$0${N} img-boot"
    e " ${W}$0${N} img-pack"
    e " ${W}$0${N} --iso=target.iso iso-pack"
    e " ${W}$0${N} --iso=target.iso iso-boot"
    e " ${W}$0${N} --usb=/dev/sdf usb-pack"
    e
    exit 1
}

#
# Trap Exit Signals & Cleanup
#
function proton_trap()
{
    # echo "${R}Trap Handler${N}"

    #
    # Umount
    #
    grep "$kvmroot" /proc/mounts && umount $kvmroot || true
    grep "$sysroot" /proc/mounts && umount $sysroot || true
    grep "$usbroot" /proc/mounts && umount $usbroot || true

    #
    # Remote Temp Files
    #
    rm -fr /tmp/genisoimage.sort
    rm -fr /tmp/rsync.exclude
}

#
#
#
function cp_kernel()
{
    dstboot=$1
    did_mount=0

    [ ! -d $sysroot ] && mkdir $sysroot
    if ! grep -q $(basename $sysroot) /proc/mounts > /dev/null; then
        mount -o loop $sysdisk $sysroot
        did_mount=1
    fi

    # find current kernels and initfs
    cur_kernel=$(ls -ot $sysroot/boot/kernel-* | head -n1 | awk '{print $8}')
    cur_initfs=$(ls -ot $sysroot/boot/initramfs-* | head -n1 | awk '{print $8}')

    cp $cur_kernel $dstboot/proton
    cp $cur_initfs $dstboot/proton.igz

    if [ "$did_mount" == "1" ]; then
        umount $sysroot
    fi
}

#
# iso_boot
# Boots the ISO Image, Cleans Up
function iso_boot()
{

    e "iso-boot: boot: ${B}$isofile${N}"

    kvm_init

    /usr/bin/kvm \
        -S \
        -m 512 \
        -cpu qemu32 \
        -name "$opt_name" \
        -boot d \
        -cdrom $isofile \
        -net nic,vlan=0,model=ne2k_pci \
        -net tap,vlan=0,ifname=$kvm_tapx,script=no,downscript=no \
        -nographic \
        -vga std \
        -vnc $kvm_vncx \
        -monitor telnet:$kvm_monx,server,nowait,nodelay \
        -usb \
        -usbdevice tablet \
        -daemonize || true

    telnet ${kvm_monx%:*} ${kvm_monx#*:} || true

    kvm_cleanup
}

#
# Open the ISO Image, Extract Squash
# @todo tempdirs?
function iso_open()
{
    mkdir -p "$isoloop"
    e "iso-open: mount $B$isoloop$N"
    mount -o loop,ro "$isofile" "$isoloop"

    e "iso-open: rsync $isoloop > $isowork/"
    mkdir -p "$isowork"
    rsync -a "$isoloop/" "$isowork/"
    umount "$isoloop"
    rm -fr "$isoloop"

    # Find SquashFS File
    # Squashfs filesystem, little endian, version 3.1, 630044716 bytes, 118638 inodes, blocksize: 131072 bytes, created: Sun Dec  7 20:56:06 2008
    sfsfile=$(find "$isowork" -type f -exec file {} \;|grep -i 'squashfs filesystem'|head -n1|cut -d: -f1)

    # Unsquash
    if [[ -x $(which unsquashfs 2>/dev/null) ]]; then
        unsquashfs -d "$syswork/" "$sfsfile"
    else
        # Mount
        mkdir -p "$sfsloop"
        mount -o loop,ro $sfsfile "$sfsloop"
        # Remove and Re-Create
        rm -fr "$syswork"
        rsync -a "$sfsloop/" "$syswork/"
        # Clean Up
        umount "$sfsloop"
        rm -fr "$sfsloop"
    fi

    e "Show Location of ISO Loop and $syswork"
    e -n "Now:\n  ${G}img-root${N} to chroot\nor:\n  ${G}img-boot${N} to boot with KVM\n"

    # touch "$proton_path/.iso-open"
}

function iso_pack()
{
    # Casper/Ubuntu Stuff
    if [[ -f "$isowork/casper/filesystem.manifest" ]]; then
        rm "$isowork/casper/filesystem.manifest"
        chroot "$syswork" dpkg-query -W --showformat='${Package} ${Version}\n' > "$isowork/casper/filesystem.manifest"
        cp "$isowork/casper/filesystem.manifest" "$isowork/casper/filesystem.manifest-desktop"
        sed -i '/casper/d'   "$isowork/casper/filesystem.manifest-desktop"
        sed -i '/ubiquity/d' "$isowork/casper/filesystem.manifest-desktop"

        # Rebuild SquashFS
        if [[ "$opt_squash" == 1 ]]; then
            e "iso-pack: re-pack $syswork > $isowork/casper/filesystem.squashfs"
            # rm "$isowork/casper/filesystem.squashfs"
            mksquashfs \
            "$syswork" \
            "$isowork/casper/filesystem.squashfs" \
            -noappend \
            -no-recovery

            rm "$isowork/casper/filesystem.size"
            du -sx --block-size=1 "$syswork" | cut -f1 > "$isowork/casper/filesystem.size"

            # rm "$isowork/md5sum.txt"
            # find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat > "$isowork/md5sum.txt"
        fi
    fi

    # Gentoo Working Image
    if [ -f "$isowork/livecd" -a -f "$isowork/image.squashfs" ]; then

        # copy kernel & initfs
        e "iso-pack: make: ${B}${isofile}${N}"
        # [ ! -d $isoroot ] && mkdir -p $isoroot
        # [ ! -d $isoroot/isolinux ] && mkdir -p $isoroot/isolinux
        # [ ! -d $isoroot/boot ] && mkdir -p $isoroot/boot/isolinux
        # @todo maybe should use the syslinux from the $sysroot ?
        # cp /usr/share/syslinux/isolinux.bin $isoroot/isolinux/
        # cp /usr/share/syslinux/chain.c32 $isoroot/isolinux/
        # cp /usr/share/syslinux/meminfo.c32 $isoroot/isolinux/
        # cp /usr/share/syslinux/pcitest.c32 $isoroot/isolinux/
        # cp /usr/share/syslinux/vesainfo.c32 $isoroot/isolinux/
        # cp /usr/share/syslinux/vesamenu.c32 $isoroot/isolinux/
        # cp $envfile $isoroot/proton.sfs
        # cp_kernel $isoroot/isolinux/
        # rsync --archive $live_boot/ $isoroot/isolinux/
        # mv $isoroot/isolinux/syslinux.cfg $isoroot/isolinux/isolinux.cfg
        touch $isowork/livecd
        # tar -zc -f $isoroot/devtool.tgz -C $proton_path/devtool/ .

        # Merge from Overlay
        e "iso-pack: merge: ${B}${proton_path}/_isoroot/${N}"
        # rsync --archive  "${proton_path}/_isoroot/" "$isoroot/"
        # mv "$isoroot/boot/syslinux.cfg" "$isoroot/boot/isolinux/"
        # mv "$isoroot/boot/syslinux.png" "$isoroot/boot/isolinux/"

        # Archive if necessary
        # [ -f $isofile ] && mv $isofile $isofile-$(date +%F-%H-%M)

        # if [ "$opt_hack" == "1" ]; then
        #     echo "${R}You are about to edit the ${B}$isoroot${N}"
        #     echo "Type: exit when done"
        #     cd $isoroot/
        #     bash
        #     echo "${Y}Done, building ISO image...${N}"
        # fi
    fi

    # Archive Previous ISO
    [ -f $isofile ] && (
        d=$(date +%F-%H-%M)
        x="$isofile-$d.iso"
        echo "iso-pack: move: $x"
        mv $isofile "$x"
    )

    # Sort Files on ISO
    isosort="$proton_path/iso.sort"
    rm -fr "$isosort"
    echo 'isolinux/boot.cat      1' >> $isosort
    echo 'isolinux/isolinux.bin  2' >> $isosort
    echo 'isolinux/isolinux.cfg  3' >> $isosort
    echo 'isolinux/isolinux.msg  4' >> $isosort
    # echo 'isolinux/proton        5' >> $isosort
    # echo 'isolinux/proton.igz    6' >> $isosort
    # echo 'livecd                 7' >> $isosort
    # echo 'proton.sfs             8' >> $isosort

    e "Building ${B}${isofile}${N}"
    # Ubuntu One
    genisoimage \
        -D \
        -J \
        -l \
        -r \
        -V "$opt_name" \
        -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
        -cache-inodes \
        -sort "$isosort" \
        -o "$isofile" \
        "$isowork/"

    # Gentoo One
    genisoimage \
        -J \
        -l \
        -r \
        -A "$opt_name Live" \
        -V "$opt_name" \
        -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
        -cache-inodes \
        -input-charset utf-8 \
        -sort "$isosort" \
        -copyright 'Edoceo, Inc.' \
        -quiet \
        -o "$isofile" \
        "$isowork/"

    # cleanup
    # rm -fr $isoroot
    # genisoimage -J -R -l \
    #   -no-emul-boot -boot-load-size 4 -boot-info-table \
    #   -b isolinux/isolinux.bin \
    #   -c isolinux/boot.cat \
    #   -o ./proton-base.iso \
    #   -A 'Edoceo Element Base' \
    #   -p 'Edoceo - http://edoceo.com/' \
    #   -publisher 'Edoceo - http://edoceo.com/' \
    #   -V 'Edoceo Element Base' \
    #   ./isoroot
    rm "$isosort"

    #
    if [ -n "$opt_burn" ]; then
        e "iso-pack: burn: ${Y}${opt_burn}${N}"
        cdrecord -sao -eject dev=$opt_burn driveropts=noburnfree speed=8 $isofile
    fi

    e "iso-pack: done: ${B}${isofile}${N}"
    e "iso-pack: next: ${G}iso-boot${N}"
}

#
# Prepare, Enter and then Cleanup the Chroot
#
function img_root()
{
    # Copy in resolv.conf
    if [[ -f "$syswork/etc/resolv.conf" ]]; then
        mv "$syswork/etc/resolv.conf" "$syswork/etc/resolv.conf.orig"
    fi
    cp /etc/resolv.conf "$syswork/etc/resolv.conf"

    # Replace .bashrc with ours
    cp "$syswork/root/.bashrc" "$syswork/root/.bashrc.orig"

    # Add some Commands to .bashrc
    # echo >> "$syswork/root/.bashrc"
    # echo "mount -t proc proc /proc"      >> "$syswork/root/.bashrc"
    # echo "mount -t sysfs sysfs /sys"     >> "$syswork/root/.bashrc"
    # echo "mount -t devpts none /dev/pts" >> "$syswork/root/.bashrc"

    mount -o bind /dev "$syswork/dev"
    mount -t devpts none "$syswork/dev/pts"
    mount -t proc proc "$syswork/proc"
    mount -t sysfs sysfs "$syswork/sys"

    # if [ -f "$syswork/etc/lsb-release" -a grep Ubuntu $syswork/etc/lsb-release ]; then
    #     e "Is Ubuntu"
    # fi

    e "\n${R}Remember:${N}\n  dpkg-divert --local --rename --add /sbin/initctl\n  ln -s /bin/true /sbin/initctl"

    chroot "$syswork/" /bin/bash || true

    umount "$syswork/sys"
    umount "$syswork/proc"
    umount "$syswork/dev/pts"
    umount "$syswork/dev"

    # Replace or Remove
    if [[ -f "$syswork/etc/resolv.conf.orig" ]]; then
        mv "$syswork/etc/resolv.conf.orig" "$syswork/etc/resolv.conf"
    else
        rm "$syswork/etc/resolv.conf"
    fi

    # Other Cleanup
    if [[ -f "$syswork/var/lib/dbus/machine-id" ]]; then
        rm -f "$syswork/var/lib/dbus/machine-id"
    fi

    e -n "Now:\n  ${G}img-boot${N} to boot with KVM\n  ${G}iso-pack${N} to rebuild iso\n"
}
#
# mounts the live system environment
#
function kvm_mount()
{

    # Standard Raw Image File
    if [ ! -f $kvmdisk ]; then
        echo "Creating $kvmdisk"
        kvm-img create -f raw $kvmdisk 6G >/dev/null
        mkfs.ext2 -F -L'root' -q $kvmdisk >/dev/null
        tune2fs -c0 -i0 $kvmdisk >/dev/null
    fi

    [ ! -d $kvmroot ] && mkdir -p $kvmroot
    mount -o loop $kvmdisk $kvmroot
}
#
# umounts the live system environment
#
function kvm_umount()
{
    sync
    umount $kvmroot
    rm -fr $kvmroot
}

function kvm_init()
{
    # Load KVM
    grep -q '^kvm ' /proc/modules || modprobe kvm || true
    grep -q '^kvm_amd ' /proc/modules || modprobe kvm_amd || true
    grep -q '^kvm_intel ' /proc/modules || modprobe kvm_intel || true
    grep -q '^tun ' /proc/modules || modprobe tun || true

    kvm_tapx=$(tunctl -b)
    kvm_monx=0.0.0.0:23$( printf %02d $(echo "$kvm_tapx"|grep -o [0-9]) )
    kvm_vncx=0.0.0.0:$( printf %02d $(echo "$kvm_tapx"|grep -o [0-9]) )

    # Activate TAP + Bridge
    #ifconfig $kvm_tapx >/dev/null 2>&1 || tunctl $kvm_tapx >/dev/null
    #(brctl show | grep -q br0) || brctl addbr br0
    (brctl show | grep -q $kvm_tapx) || brctl addif br0 $kvm_tapx
    ifconfig $kvm_tapx up 0.0.0.0 promisc

    e "kvm-init: Monitor at ${G}${kvm_monx}${N}; VNC:${G}${kvm_vncx}${N}"
}

#
#
#
function kvm_cleanup()
{
    brctl delif br0 $kvm_tapx
    ifconfig $kvm_tapx down
    tunctl -d $kvm_tapx > /dev/null
}

#
# Main
#

if [[ $# == 0 ]]; then
    proton_help
    exit 1
fi

for x in $@
do
    shift
    case "${x}" in
    +burn*)
        iso_burn=$(echo "${x}"|cut -d= -f2)
        if [ -z "$iso_burn" -o "$iso_burn" == "+burn" ]; then
            iso_burn=$(readlink -f /dev/cdrom)
        fi
        if [ ! -b $iso_burn ]; then
            proton_help "$iso_burn is not a block device"
        fi
        ;;
    +disk\=*)
        kvm_disk=$(echo "${x}"|cut -d= -f2)
        ;;
#    +hack)
#        opt_hack=1
#        ;;
    --iso\=*)
        isofile=${x#*=}
        ;;
    --name\=*)
        kvm_name=${x#*=}
        ;;
#    +tiny*)
#        opt_tiny=${x#*=}
#        if [ -n "$opt_tiny" ]; then
#            opt_tiny="yes"
#        fi
#        ;;
    --usb\=*)
        # usb_part=$(echo "${x}"|cut -d= -f2)
        usb_part=${x#*=}
        ;;
    --no-squash)
        opt_squash=0
        ;;
    # Dump our Configuration and Options
    cfg-dump)

        # echo "Configuration Dump:"
        # Dump lowercase vars
        # set | grep '^[a-z_]\+=' | sort
        e
        e "Configuration Details:"
        e "proton_path= $proton_path"
        e "envdisk=    $envdisk"
        e "envfile=    $envfile"
        e "envroot=    $envroot"
        e "isofile=    $isofile"
        e "isoloop=    $isoloop"
        e "isowork=    $isowork"
        e "kvmdisk=    $kvmdisk"
        e "kvmroot=    $kvmroot"
        e "live_boot=  $live_boot"
        e "live_name=  $live_name"
        e "live_over=  $live_over"
        e "opt_burn=   $opt_burn"
        e "opt_file=   $opt_file"
        e "opt_name=   $opt_name"
        e "opt_squash= $opt_squash=1"
        e "sfsloop=    $sfsloop"
        e "sysdisk=    $sysdisk"
        e "sysroot=    $sysroot"
        e "syswork=    $syswork"

        # sysroot holds our build environment
        # echo $sysdisk
        # echo $sysroot
        # # echo $# envroot holds our build->staging area
        # echo $envdisk
        # echo $envfile
        # echo $envroot
        # # echo $# where the files live before packing into ISO
        # echo $isofile
        # echo $isoroot
        # echo $# where the KVM image is mounted too for cloning
        # echo $# the name of the file that is the kvm boot disk
        # echo $kvmdisk
        # echo $kvmroot
        # echo $# Should only be $ramroot
        # echo $# ramfile=$isoroot/sysroot/proton.igz
        # echo $# ramroot=$proton_path/ramroot/
        # echo $#
        # echo $sysfile
        # echo $# where the usb gets mounted and built
        # echo $usbroot

        echo "Options:"
        echo "opt_burn = $opt_burn"
        echo "opt_hack = $opt_hack"
        echo "opt_tiny = $opt_tiny"
        echo "  Purge extra stuff during ${G}img-pack${N}"
        exit
        ;;
    # Extract the ISO and SquashFS
    iso-open)
        if [[ ! -f "$isofile" ]]; then
            proton_help "${R}I need an ISO file to operate on${N}\n  $0 --iso=${B}somefile.iso${N} iso-open\n  Maybe one of:\n  $(find . -name '*.iso'|xargs)\n"
        fi
        if [[ -d "$syswork" ]]; then
            proton_help "${R}I won't overwrite $syswork, manually remove${N}"
        fi
        iso_open
        ;;
    # Enter the Bootable System via Chroot
    img-root)
        img_root
        ;;
    # Boots the System located on $sysdisk
    sys-boot)

        kvmdisk=$sysdisk

        echo "Mounting: $kvmdisk at $kvmroot"
        kvm_mount
        [ ! -d $kvmroot/boot ] && mkdir -p $kvmroot/boot
        # add boot loader to new image
        if [ ! -f $kvmroot/boot/ldlinux.sys ]; then
            echo "Install Bootloader"
            extlinux --install $kvmroot/boot > /dev/null
        fi
        #cp /usr/share/syslinux/vesamenu.c32 $kvmroot/boot/vesamenu.c32
        #cp $livedir/devtool/_isoboot/display.msg $kvmroot/boot/display.msg
        #cp $livedir/devtool/_isoboot/syslinux.png $kvmroot/boot/syslinux.png

        # sync $sysroot to $sysdisk
        # @note the /tmp/.private directory is giving some issues - how to fix?
        # [ -d $kvmroot/tmp/.private ] && chattr -i
        # rsync -av --delete --dry-run --exclude='extlinux.sys' --exclude='.private' --exclude='usr/portage' --exclude='usr/src' $sysroot/ $kvmroot/

        # update boot item for KVM Instance
        echo "Update Bootloader Config"
        rm -fr $kvmroot/boot/syslinux.cfg
        (
            echo "# # $live_name - sys-boot /boot/syslinux.cfg"
            echo ""
            echo "DEFAULT proton"
            echo "PROMPT 1"
            echo "TIMEOUT 50"
            echo ""
            echo "LABEL proton"
            echo "    KERNEL $live_name"
            echo "    INITRD $live_name.igz"
            echo "    APPEND console=tty1 init=/linuxrc real_root=/dev/hda root=/dev/ram0 splash=verbose vga=791 noapm noevms nogpm nolvm nomdadm nonfs nopcmcia noscsi dodhcp"
            echo ""
            echo "LABEL proton-s"
            echo "    KERNEL $live_name"
            echo "    INITRD $live_name.igz"
            echo "    APPEND console=tty1 init=/linuxrc real_root=/dev/hda root=/dev/ram0 splash=verbose vga=791 noapm noevms nogpm nolvm nomdadm nonfs nopcmcia noscsi nox dodhcp S"
            echo ""
        ) > $kvmroot/boot/syslinux.cfg

        # unmount & cleanup
        echo "Unmount"
        kvm_umount

        echo "Boot $(basename $kvmdisk)"
        kvm_init

        /usr/bin/kvm \
           -S \
           -m 512 \
           -cpu qemu32 \
           -name $(basename $kvmdisk) \
           -boot c \
           -drive file=$kvmdisk \
           -net nic,vlan=0,macaddr=00:ed:0c:e0:72:01,model=e1000 \
           -net tap,vlan=0,ifname=$kvm_tapx,script=no,downscript=no \
           -nographic \
           -vga cirrus \
           -vnc $kvm_vncx \
           -monitor telnet:$kvm_monx,server,nowait,nodelay \
           -usb \
           -usbdevice tablet &

        sleep 3

        telnet localhost ${kvm_monx##*:} || true

        kvm_cleanup

        #echo "Check differences with:"
        #echo "diff --brief --recursive envroot/etc kvmroot/etc"
        #echo "diff --brief --recursive envroot/home kvmroot/home"
        #echo "changes need to be copied into sysroot so they will not be lost"

        echo "${B}$kvmdisk${N} has been updated"
        # echo "$CYAN now use sys-diff.sh to examine the differences${N}"
        echo "Next: ${G}img-pack${N}"
        ;;
    # Clone and Prune /sysdisk to /envroot
    img-pack)
        #
        # This creates a directory (envroot) that is a clone of sysroot that has much stuff removed
        #   It's intentionally had a bundle of files ignore during an rsync.

        #  Does an rsync from the Build Source (sysroot) to the Environment Staging Area (envroot)
        #  Then SquashFS the Environment to element.sfs

        e "Cloning ${B}$syswork${N} => ${B}$envroot${N}"

        # build list of things to exclude
        outfile=/tmp/rsync.exclude
        rm -fr $outfile
        # exclude these patterns
        echo '.*history' > $outfile
        echo '.cache' >> $outfile
        echo '.ccache' >> $outfile
        echo '.distcc' >> $outfile
        echo '.gconf' >> $outfile
        echo '.keep*' >> $outfile
        echo '.revdep*' >> $outfile
        echo '.ssh' >> $outfile
        echo '.subversion' >> $outfile
        echo '.xchat2' >> $outfile
        echo '/boot/*' >> $outfile
        echo '/etc/ssh/ssh_host_*' >> $outfile
        # don't take changes to home, those have to be manual
        echo '/home/*' >> $outfile
        echo '/proc/*' >> $outfile
        # don't take changes to root, those have to be manual
        echo '/root/*' >> $outfile
        echo '/sys/*' >> $outfile
        echo '/tmp/*' >> $outfile
        # These are the ones we want really clean, so exclude on the front
        echo '/usr/include/*' >> $outfile
        # echo 'usr/lib/gcc' >> $outfile
        # echo 'usr/livecd/*' >> $outfile
        echo '/usr/portage/*' >> $outfile
        echo '/usr/src/*' >> $outfile
        echo '/var/cache/edb/*' >> $outfile
        echo '/var/cache/fontconfig/*' >> $outfile
        echo '/var/cache/genkernel/*' >> $outfile
        echo '/var/db/pkg/*' >> $outfile
        echo '/var/lock/*' >> $outfile
        echo '/var/run/*' >> $outfile
        echo '/var/tmp/*' >> $outfile

        # Copy $sysroot to $envroot
        mount -o loop $sysdisk $sysroot
        rsync \
            --archive \
            --delete \
            --one-file-system \
            --exclude-from=/tmp/rsync.exclude \
            $sysroot \
            $envroot
        sync
        umount $sysroot

        #
        # Purge $envroot
        #
        outfile=/tmp/purge.list
        rm -fr $outfile
        # path patterns
        echo '/etc/X11/xorg.conf' >> $outfile
        echo '/etc/fstab' >> $outfile
        echo '/etc/mtab' >> $outfile
        echo '/etc/udev/rules.d/*persistent*' >> $outfile
        echo '/boot/*' >> $outfile
        echo '/root/.gconf/*' >> $outfile
        # echo '/lib/modules/*' >> $outfile
        echo '/home/*/.mozilla/firefox/*/Cache' >> $outfile
        echo '/usr/include/*' >> $outfile
        # echo '/usr/lib/portage/*' >> $outfile
        echo '/usr/lib*/*.a' >> $outfile
        echo '/usr/lib*/*.la' >> $outfile
        echo '/usr/libexec/gcc' >> $outfile
        echo '/usr/portage/*' >> $outfile
        echo '/usr/share/gtk-doc/*' >> $outfile
        echo '/usr/share/doc/*' >> $outfile
        echo '/usr/src/*' >> $outfile
        echo '/var/cache/*' >> $outfile
        #echo '/var/cache/edb/*' >> $outfile
        #echo '/var/cache/fontconfig/*' >> $outfile
        #echo '/var/cache/genkernel/*' >> $outfile
        echo '/var/db/*' >> $outfile
        # echo '/var/db/pkg/*' >> $outfile
        echo '/var/lib/syslog-ng.persist' >> $outfile
        echo '/var/lib/dhcpcd/*' >> $outfile
        echo '/var/lib/init.d/*' >> $outfile
        echo '/var/tmp/*' >> $outfile

        ( cd $envroot && find -type d -name '.ccache' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find -type d -name '.distcc' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find -type d -name '.revdep*' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find -type d -name '.ssh' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find -type d -name '.subversion' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find -type d -name '.thumbnails' ) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find var/log -type f) | sed 's/^\.\///' >> $outfile
        ( cd $envroot && find var/run -type f) | sed 's/^\.\///' >> $outfile
        # Hidden Files
        # ( cd $sysroot; find . -xdev -mindepth 1 -type d -name '.*') | sed 's/^\.\///' >> $out

        # remove empty dirs
        #echo "Empty Directories: ${B}"
        #( cd $envroot && find home lib sbin usr -depth -type d -empty)
        #echo -n "${N}"

        # make really small?
        if [ "$opt_tiny" == "tiny" ]; then

            # stuff not often used on live cds
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-admin/eselect*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-admin/localepurge*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-arch/rpm2targz*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-benchmarks/*/CONTENTS >> $outfile
            #awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-portage/*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/autoconf*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/automake*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/bison*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/binutils*/CONTENTS >> $outfile
            # awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/gcc*/CONTENTS | grep -v 'i686-pc-linux-gnu' >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-devel/make*/CONTENTS >> $outfile
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-kernel/genkernel*/CONTENTS >> $outfile

            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/app-admin/python-updater*/CONTENTS >> $outfile
            # awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/dev-util/metro*/CONTENTS >> $outfile
            # awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/edoceo/atom*/CONTENTS >> $outfile
            # awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/edoceo/element-base*/CONTENTS >> $outfile

            # man pages!
            awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/sys-apps/man-pages*/CONTENTS >> $outfile
            # awk '/obj|sym/ { print $2 }' $sysroot/var/db/pkg/www-servers/apache*/CONTENTS >> $outfile
            # equery f texinfo | grep -v "* Contents of " >> ~/USELESSFILELIST
            # equery f flex | grep -v "* Contents of " >> ~/USELESSFILELIST
            # equery f m4 | grep -v "* Contents of " >> ~/USELESSFILELIST
            # equery f patch | grep -v "* Contents of " >> ~/USELESSFILELIST
        fi

        # remove lines containing 'bin/'
        # sed -i 's/^.*\/bin\/.*$//' $outfile
        # remove lines containing 'lib/'
        # sed 's/^.*lib\/.*$//' /tmp/prune.list > /tmp/prune.sed

        # remove leading /
        sed -i 's/^\///' $outfile

        # File Pattern Specific Stuffs
        # find $envroot -xdev -type f -name '.keep*' >> $outfile
        (
            x=$(wc -l $outfile|awk '{print $1}')
            echo -en "Purging $x paths from ${B}$envroot${N} ($outfile)${R}"
            cd $envroot
            while read f; do
                rm -fr -- "./$f"
            done < $outfile
            echo -en "${N}"
        )

        #
        # Merge Template Overlay Files
        #
        if [ -d $live_over ]; then
            echo "Merging $live_over => $envroot"
            rsync --archive --verbose $live_over/ $envroot/
        fi

        # build md5sums
        # (
        #     cd $envroot
        #     find -type f -maxdepth 1 -exec md5sum --binary {} \; > element.md5
        # )

        # Change permissions to allow the file to be sent by thttpd for PXE-boot
        #  chmod 666 /mnt/custom/customcd/isoroot/sysrcd.{dat,md5}

        # kvm_umount

        #echo "$thiscmd:$G $envfile created and copied to $isoroot${N}"
        # echo "Use ${G}env-boot.sh${N} to run here and maybe update"
        e "Next: ${G}env-pack${N}"
        ;;
    # Packs the Environment to $envboot.
    env-pack)
        t0=$(date +%s)
        echo "env-pack: ${B}$envroot${N} => ${B}$envfile${N}"

        # update init.d & conf.d times
        find $envroot/etc -type f -exec touch -d 2011-01-01 {} \;

        # Make SquashFS Image
        mksquashfs $envroot $envfile -noappend -no-recovery >/dev/null
        chmod 0644 $envfile
        # Can this be optimised?  Likely not since we must extract full thing
        # out=/tmp/mksquashfs.sort
        # echo '/sbin -32767' > $out
        # echo '/etc -32766' >> $out
        # echo '/lib/modules -32765' >> $out
        # echo '/lib -32764' >> $out
        # echo '/bin -32764' >> $out
        # -sort /tmp/mksquashfs.sort
        t1=$(date +%s)
        ts=$(( $t1 - $t0 ))
        echo "Time: $ts seconds"
        echo "Next: ${Y}iso-pack${N} or ${Y}usb-pack ${W}/dev/sd#${N}"
        echo "env-pack: Use ${G}iso-pack${N} or ${G}usb-pack ${Y}+usb=/dev/sd#${N}"
        # echo "Use ${G}iso-pack.sh${N} to rebuild ISO"
        # echo "Use ${G}usb-pack.sh ${Y}+usb=/dev/usb1${N} pack onto a USB stick - point to unmounted partition"
        ;;
    # Pack the $envfile and other stuff to an ISO Image
    iso-pack)
        if [[ ! -d "$isowork" ]]; then
            proton_help "I need the ${isowork} directory"
        fi
        if [[ ! -d "$syswork" ]]; then
            proton_help "I need the ${syswork} directory"
        fi
        iso_pack
        ;;
    # Boot the ISO Image that was Just Created
    iso-boot)
        if [[ ! -f "$isofile" ]]; then
            proton_help "${R}I need an ISO file to operate on${N}\n  $0 --iso=${B}somefile.iso${N} iso-open\n  Maybe one of:\n  $(find . -name '*.iso'|xargs)\n"
        fi
        iso_boot
        ;;
    usb-pack)

        # Check for SquashFS
        if [[ ! -d "$isowork" ]]; then
            e "usb-pack: ${R}Need to have ${B}${isowork}${R} present"
            exit
        fi

        if [ -b $usb_part ]; then
            # if raw device, partition then move target to partition
            # x=$( find /sys/block -name $(basename $usb_part) )
            x=$( find /sys/devices -name $(basename $usb_part) )
            if [ ! -f $x/partition ]; then
                e "usb-pack: ${R}partitioning${N}"
                dd if=/dev/zero of=$usb_part bs=512 count=4 > /dev/null
                dd if=/usr/share/syslinux/mbr.bin of=$usb_part bs=512 count=1 > /dev/null
                # @todo which of these is right? use fdisk to find out
                # echo '0,,83,*' | sfdisk $usb_part > /dev/null
                # echo '48,1024,83,*' | sfdisk --DOS -uS $usb_part > /dev/null
                # echo '62,,83,*' | sfdisk $usb_part > /dev/null
                sfdisk --re-read $usb_part > /dev/null
                sleep 1
                usb_part=${usb_part}1
                # zero the first 512 bytes, sqee fdisk(8)
                # dd if=/dev/zero of=$usb_part bs=512 count=1
            fi

            # if partition, make file system (if necessary and mount)
            x=$( find /sys -name $(basename $usb_part) | head -n1 )
            if [ -f $x/partition ]; then
                # needs a file system?
                if ! tune2fs -l $usb_part >/dev/null ; then
                    e "usb-pack: ${R}creating filesystem${N}"
                    # mkdosfs -n "Element Live" $usb_part
                    mkfs.ext2 -L'Element Live' $usb_part >/dev/null
                    tune2fs -c0 -i0 $usb_part >/dev/null
                fi
            fi
            [ -d $usbroot ] || mkdir -p $usbroot
            mount $usb_part $usbroot
        fi

         if ! grep -q $(basename $usb_part) /proc/mounts ; then
            if [ -d $usb_part ]; then
                echo "usb-pack: ${R}the target must be a device or mounted directory${N}"
                exit_with_help
            fi
            mount $usb_part $usbroot
         fi

        e "usb-pack: ${W}packaging...${N}"

         # Make USB Bootable
        e "usb-pack: ${B}adding bootloader...${N}"
        [ ! -d $usbroot/extlinux ] && mkdir -p $usbroot/extlinux
        cp_kernel $usbroot/extlinux/
        extlinux --install $usbroot/extlinux
        rsync --archive $proton_path/_isoboot/ $usbroot/extlinux/
        # copy these goodie to the usb location

        # Merge from Overlay
        e "usb-pack: ${B}$proton_path/_isoroot/${N}"
        rsync --archive $proton_path/_isoroot/ $usbroot/

        # envfile=$usbroot/proton.sfs
        e "usb-pack: copy ${B}$envfile${N}"
        # mksquashfs $envroot $envfile -noappend -no-recovery >/dev/null

        touch $usbroot/livecd
        # find $usbroot -exec touch {} \;

        e "usb-pack: waiting for device to settle..."
        sync
        umount $usbroot
        rm -fr $usbroot
        e "usb-pack: ${G}$usb_part${N} is ready for use"
        ;;
    -h|--help)
        proton_help
        ;;
    *)
        e "proton: unhandled argument: ${R}${x}${N}"
    esac
done

