Atlas SoC GHRD Code
===================

Compile-Instructions
--------------------

This assumes the variable `$QUARTUS_SH` points to a script to add the
Quartus and SoC EDS tools to the path. One script that does this is the
`embedded_command_shell.sh` that is part of the SoC EDS installation.
This might be located at `~/Quartus/16.0/embedded/embedded_command_shell.sh`
or wherever the tools were installed.

    git clone https://github.com/dwesterg/atlas-soc-ghrd.git
    pushd atlas-soc-ghrd
    "$QUARTUS_SH" make all
    ./scripts/atlas_socdk_setup_angstrom_1.7.sh
    sudo ./scripts/atlas_sd_card_image_creation.sh\
     --sd_fat=sd_fat.tar.gz\
     --zImage=setup-scripts/deploy/glibc/images/atlas_sockit/zImage\
     --dtb=setup-scripts/deploy/glibc/images/atlas_sockit/zImage-socfpga_cyclone5_de0_sockit.dtb\
     --ext3=setup-scripts/deploy/glibc/images/atlas_sockit/atlas-soc-image-atlas_sockit.ext3\
     --name=atlas_sdcard_v1.1-custom.img
