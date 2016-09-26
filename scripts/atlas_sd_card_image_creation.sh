#!/bin/bash

# typical invocation from default location
#[]$ ./atlas_sd_card_image_creation.sh \
#	--sd_fat="./atlas-soc-ghrd/sd_fat.tar.gz" \
#	--zImage="./setup-scripts/deploy/glibc/images/atlas_sockit/zImage" \
#	--dtb="./setup-scripts/deploy/glibc/images/atlas_sockit/zImage-socfpga_cyclone5_de0_sockit.dtb" \
#	--ext3="./setup-scripts/deploy/glibc/images/atlas_sockit/atlas-soc-image-atlas_sockit.ext3" \
#	--name="atlas_sdcard_v1.0rc2.img"

PROGRAM_NAME="$(basename ${0})"
THE_SD_FAT_TAR_GZ=
THE_LINUX_ZIMAGE=
THE_DTB_FILE=
THE_ROOTFS_EXT3_IMAGE=
MY_SD_CARD_IMAGE=

for i in "$@"
do
case $i in
	-h|--help)
		echo ""
		echo "USAGE: ${PROGRAM_NAME} \\"
		echo "	--sd_fat=<path to ATLAS GHRD sd_fat.tar.gz> \\"
		echo "	--zImage=<path to ATLAS Angstrom zImage> \\"
		echo "	--dtb=<path to ATLAS Angstrom dtb file> \\"
		echo "	--ext3=<path to ATLAS Angstrom ext3> \\"
		echo "	--name=<name of sd card image>"
		echo ""
		exit 1
	;;
	--sd_fat=*)
		THE_SD_FAT_TAR_GZ="${i#*=}"
		shift
	;;
	--zImage=*)
		THE_LINUX_ZIMAGE="${i#*=}"
		shift
	;;
	--dtb=*)
		THE_DTB_FILE="${i#*=}"
		shift
	;;
	--ext3=*)
		THE_ROOTFS_EXT3_IMAGE="${i#*=}"
		shift
	;;
	--name=*)
		MY_SD_CARD_IMAGE="${i#*=}"
		shift
	;;
	*)
		# unknown option
	;;
esac
done

# verify root user is running script
[ "${EUID}" -ne 0 ] && {
		echo ""
		echo "ERROR: script must be run as root, use 'sudo'"
		echo ""
		exit 1
}

###############################################################################
#
# Change these variables to apply to your environment
#
###############################################################################
MY_SD_CARD_IMAGE_1M_BLOCKS="3k"

###############################################################################
#
# These are variables used by the script
#
###############################################################################
MY_SD_EXT3_MNT="$(mktemp --tmpdir=. --directory TMP_SD_EXT3_MNT.XXXX)"
MY_SD_FAT_MNT="$(mktemp --tmpdir=. --directory TMP_SD_FAT_MNT.XXXX)"
MY_TMP_TAR="$(mktemp --tmpdir=. --directory TMP_TAR.XXXX)"

###############################################################################
#
# Verify that all the required input directories and files exist
#
###############################################################################

[ -f "${THE_LINUX_ZIMAGE:?must specify --zImage argument}" ] || {
	echo "ERROR: could not locate file provided by THE_LINUX_ZIMAGE"
	exit 1
}

[ -f "${THE_DTB_FILE:?must specify --dtb argument}" ] || {
	echo "ERROR: could not locate file provided by THE_DTB_FILE"
	exit 1
}

[ -f "${THE_ROOTFS_EXT3_IMAGE:?must specify --ext3 argument}" ] || {
	echo "ERROR: could not locate file provided by THE_ROOTFS_EXT3_IMAGE"
	exit 1
}

[ -f "${THE_SD_FAT_TAR_GZ:?must specify --sd_fat argument}" ] || {
	echo "ERROR: could not locate file provided by THE_SD_FAT_TAR_GZ"
	exit 1
}

[ -d "${MY_SD_EXT3_MNT}" ] || {
	echo "ERROR: could not locate temp directory '${MY_SD_EXT3_MNT}'"
	exit 1
}

[ -d "${MY_SD_FAT_MNT}" ] || {
	echo "ERROR: could not locate temp directory '${MY_SD_FAT_MNT}'"
	exit 1
}

[ -d "${MY_TMP_TAR}" ] || {
	echo "ERROR: could not locate temp directory '${MY_TMP_TAR}'"
	exit 1
}

###############################################################################
#
# Verify that none of our working files or directories already exist
#
###############################################################################
[ -f "${MY_SD_CARD_IMAGE:?must specify --name argument}" ] && {
	echo "ERROR: file \"${MY_SD_CARD_IMAGE}\" already exists, please remove it."
	exit 1
}

echo "Creating SD card image file filled with 0xFF pattern."
dd if=/dev/zero bs=1M count=${MY_SD_CARD_IMAGE_1M_BLOCKS} 2> /dev/null | tr '\000' '\377' > ${MY_SD_CARD_IMAGE} || { echo "ERROR"; exit 1; }

echo "Attaching SD card image file to loop device."
MY_LOOP_DEV=$(losetup --show -f ${MY_SD_CARD_IMAGE}) || { echo "ERROR"; exit 1; }

echo "Creating partition table in MBR of SD card image file."
fdisk ${MY_LOOP_DEV} <<EOF > /dev/null 2>&1
n
p
3

+10M
n
p
1

+500M
n
p
2


t
1
0b
t
2
83
t
3
a2
w
EOF

echo "Detaching SD card image file from loop device."
losetup -d ${MY_LOOP_DEV} || { echo "ERROR"; exit 1; }

echo "Attaching SD card image file to loop device with partition scan."
MY_LOOP_DEV=$(losetup --show -f ${MY_SD_CARD_IMAGE}) || { echo "ERROR"; exit 1; }

echo "Probe partitions."
partprobe "${MY_LOOP_DEV}" || { echo "ERROR"; exit 1; }

echo "Verify loop partition 1 exists."
[ -b "${MY_LOOP_DEV}p1" ] || { echo "ERROR"; exit 1; }

echo "Verify loop partition 2 exists."
[ -b "${MY_LOOP_DEV}p2" ] || { echo "ERROR"; exit 1; }

echo "Verify loop partition 3 exists."
[ -b "${MY_LOOP_DEV}p3" ] || { echo "ERROR"; exit 1; }

echo "Initializing FAT volume in partition 1 of SD card image file."
mkfs -t vfat -F 32 ${MY_LOOP_DEV}p1 > /dev/null || { echo "ERROR"; exit 1; }

echo "Mounting FAT partition of SD card image file."
mount ${MY_LOOP_DEV}p1 ${MY_SD_FAT_MNT} || { echo "ERROR"; exit 1; }

echo "Extracting sd_fat.tar.gz."
tar -C ${MY_TMP_TAR} -xf ${THE_SD_FAT_TAR_GZ} || { echo "ERROR"; exit 1; }

echo "Copying into FAT partition."
cp -R ${MY_TMP_TAR}/* ${MY_SD_FAT_MNT} || { echo "ERROR"; exit 1; }

echo "Copying kernel zImage into FAT partition."
cp ${THE_LINUX_ZIMAGE} ${MY_SD_FAT_MNT}/ || { echo "ERROR"; exit 1; }

echo "Copying DTB into FAT partition."
cp ${THE_DTB_FILE} ${MY_SD_FAT_MNT}/ || { echo "ERROR"; exit 1; }

echo "Copying preloader image into partition 3 of SD card image file."
[ -f "${MY_SD_FAT_MNT}/ATLAS_SOC_GHRD/preloader-mkpimage.bin" ] || {
	echo "ERROR: could not locate preloader image file"
	exit 1
}
dd if="${MY_SD_FAT_MNT}/ATLAS_SOC_GHRD/preloader-mkpimage.bin" of=${MY_LOOP_DEV}p3 2> /dev/null || { echo "ERROR"; exit 1; }

echo "Unmount the FAT partition."
umount ${MY_SD_FAT_MNT} || { echo "ERROR"; exit 1; }

echo "Copy the rootfs ext3 image into partition 2 of SD card image file."
dd if=${THE_ROOTFS_EXT3_IMAGE} of=${MY_LOOP_DEV}p2 2> /dev/null || { echo "ERROR"; exit 1; }

echo "Resizing the ext3 file system to fill partition 2 of SD card image file."
resize2fs ${MY_LOOP_DEV}p2 > /dev/null 2>&1 || { echo "ERROR"; exit 1; }

echo "Mounting EXT3 partition of SD card image file."
mount ${MY_LOOP_DEV}p2 ${MY_SD_EXT3_MNT} || { echo "ERROR"; exit 1; }

echo "Creating Image Date String."
IMAGE_DATE_STRING="$(date --utc +'%Y-%m-%d %H:%M:%S %Z')"

echo "Editing /usr/share/atlas-soc-101/develop.html"
sed -i~ -e "s/PutVersionHere/${MY_SD_CARD_IMAGE}/" -e "s/PutDateHere/${IMAGE_DATE_STRING}/" ${MY_SD_EXT3_MNT}/usr/share/atlas-soc-101/develop.html || { echo "ERROR"; exit 1; }

echo "Creating /etc/atlas-release"
echo "SD_CARD_IMAGE_NAME='${MY_SD_CARD_IMAGE}'" > ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "IMAGE_TIMESTAMP='${IMAGE_DATE_STRING}'" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "PRELOADER_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${MY_TMP_TAR}/ATLAS_SOC_GHRD/preloader-mkpimage.bin" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "UBOOT_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${MY_TMP_TAR}/ATLAS_SOC_GHRD/u-boot.img" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "UBOOT_SCR_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${MY_TMP_TAR}/u-boot.scr" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "RBF_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${MY_TMP_TAR}/ATLAS_SOC_GHRD/output_files/ATLAS_SOC_GHRD.rbf" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "ZIMAGE_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${THE_LINUX_ZIMAGE}" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo -n "DTB_MD5SUM='" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
cat "${THE_DTB_FILE}" | md5sum | cut -d ' ' -f 1 | tr '\012' '\047' >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }
echo "" >> ${MY_SD_EXT3_MNT}/etc/atlas-release || { echo "ERROR"; exit 1; }

echo "Unmount the EXT3 partition."
umount ${MY_SD_EXT3_MNT} || { echo "ERROR"; exit 1; }

echo "Detaching SD card image file from loop device."
losetup -d ${MY_LOOP_DEV} || { echo "ERROR"; exit 1; }

echo "Removing temporary working directories."
rm -Rf ${MY_SD_EXT3_MNT} ${MY_SD_FAT_MNT} ${MY_TMP_TAR} || { echo "ERROR"; exit 1; }

echo "SD card image created."
echo "The file ${MY_SD_CARD_IMAGE} is now ready to be copied onto an SD card."

