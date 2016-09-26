#!/bin/bash

# Clone 1.7 angstrom repo
git clone git://github.com/Angstrom-distribution/setup-scripts.git

# Add sources to layers.txt
echo "meta-altera,git://github.com/dwesterg/meta-altera.git,angstrom-v2014.12-yocto1.7,HEAD" >> setup-scripts/sources/layers.txt
echo "meta-altera-refdes,git://github.com/dwesterg/meta-altera-refdes.git,angstrom-v2014.12-yocto1.7,HEAD" >> setup-scripts/sources/layers.txt

#sed -i 's/meta-linaro.git.*/meta-linaro,git:\/\/git.linaro.org\/openembedded\/meta-linaro.git,master,HEAD/' setup-scripts/sources/layers.txt


# add BBLayers
sed -i '/meta-96boards/a \ \ \$\{TOPDIR\}\/sources\/meta-altera-refdes \\' setup-scripts/conf/bblayers.conf
sed -i '/meta-96boards/a \ \ \$\{TOPDIR\}\/sources\/meta-altera \\' setup-scripts/conf/bblayers.conf

# meta-dominion contains no usable recipes: remove it
sed -i '/meta-dominion/d' setup-scripts/sources/layers.txt setup-scripts/conf/bblayers.conf

# disable kde4 repo  / gitorious gone
#sed -i '/meta-kde4/d' setup-scripts/sources/layers.txt
#sed -i '/meta-kde4/d' setup-scripts/conf/bblayers.conf

# gumstix on gitorious too

#sed -i '/meta-gumstix-community/d' setup-scripts/sources/layers.txt
#sed -i '/meta-gumstix-community/d' setup-scripts/conf/bblayers.conf

sed -i '/rm_work/d' setup-scripts/conf/local.conf

# Remove guard against dash
sed -i '/\n/!N;/\n.*Look for dash/{:a;/\n$/d;N;ba};P;D' setup-scripts/oebb.sh

pushd setup-scripts
MACHINE=atlas_sockit ./oebb.sh config atlas_sockit
popd

# Change download and cache dirs
sed -i '/DL_DIR/d' setup-scripts/conf/site.conf
sed -i '/SSTATE_DIR/d' setup-scripts/conf/site.conf
echo "DL_DIR = \"\${TOPDIR}/../downloads\"" >> setup-scripts/conf/site.conf
echo "SSTATE_DIR = \"\${TOPDIR}/../ang_sstate_cache\"" >> setup-scripts/conf/site.conf

# this qemu doesnt build with gcc5
rm setup-scripts/sources/meta-linaro/meta-linaro/recipes-devtools/qemu/qemu_git.bb

# don't append to non-existing recipes
rm -f setup-scripts/sources/meta-altera/recipes-core/systemd/systemd_218.bbappend\
 setup-scripts/sources/meta-angstrom/recipes-core/systemd/systemd_219.bbappend\
 setup-scripts/sources/meta-angstrom/recipes-tweaks/systemd/libnmglib_%.bbappend\
 setup-scripts/sources/meta-atmel/recipes-qt/qt4/qt4-embedded_4.8.5.bbappend\
 setup-scripts/sources/meta-kde4/recipes-misc-support/qt4-native_4.8.5.bbappend\
 setup-scripts/sources/meta-kde4/recipes-misc-support/qt4-x11-free_4.8.5.bbappend\
 setup-scripts/sources/meta-raspberrypi/recipes-multimedia/gstreamer/gstreamer1.0-plugins-bad_1.4.0.bbappend

# remove all deprecated PRINC assignments
find setup-scripts/sources -name \*.bb -o -name \*.bbappend -print0 |\
 xargs -0 sed -i 's/^PRINC\b/#PRINC/'

# Patch build to silence errors & warnings
cat <<"EOF" >>setup-scripts/conf/local.conf

# Silence some warnings
DEPENDS_append_pn-gvfs                      = " gtk+3"
DEPENDS_append_pn-imagemagick               = " libxt"
FILES_gvfs_append_pn-gvfs                   = " ${datadir}/bash-completion"
PREFERRED_PROVIDER_glibc                    = "glibc"
PREFERRED_PROVIDER_libevent                 = "libevent"
PREFERRED_PROVIDER_python-distribute-native = "python-distribute-native"
PREFERRED_PROVIDER_virtual/fftw             = "fftw"
PREFERRED_VERSION_remove_systemd            = "226%"
RDEPENDS_append_gnome-desktop               = " python-core"
RDEPENDS_append_gnome-panel                 = " python-core"
SPDXLICENSEMAP[GFDLv1.1]                    = "GFDL-1.1"
SRC_URI_remove_pn-u-boot-edison             = "file://${MACHINE}.env"
SRC_URI_remove_pn-u-boot-edison-fw-utils    = "file://${MACHINE}.env"
EOF

cd setup-scripts
source environment-angstrom-v2014.12

#mkdir sources/meta-altera-refdes/recipes-kernel/gator
#cp ../gator_git.bbappend sources/meta-altera-refdes/recipes-kernel/gator

export KERNEL_PROVIDER="linux-altera"
export BB_ENV_EXTRAWHITE="${BB_ENV_EXTRAWHITE} KERNEL_PROVIDER"

bitbake atlas-soc-image
