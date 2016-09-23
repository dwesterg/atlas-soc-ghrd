################################################
#
# Makefile to Manage QuartusII/QSys Design
#
# Copyright Altera (c) 2014
# All Rights Reserved
#
################################################

SHELL := /bin/bash

.SUFFIXES: # Delete the default suffixes
.DEFAULT_GOAL := help

include mks/default.mk

################################################
# Configuration

# Source 
TCL_SOURCE = $(wildcard scripts/*.tcl)
QUARTUS_HDL_SOURCE = $(wildcard src/*.v) $(wildcard src/*.vhd) $(wildcard src/*.sv)
QUARTUS_MISC_SOURCE = $(wildcard src/*.stp) $(wildcard src/*.sdc)
PROJECT_ASSIGN_SCRIPTS = $(filter scripts/create_ghrd_quartus_%.tcl,$(TCL_SOURCE))

QSYS_ADD_COMP_TCLS := $(sort $(filter-out\
 %_fft128_components.tcl,$(wildcard scripts/qsys_add_*.tcl)))

#UBOOT_PATCHES = patches/soc_workshop_uboot_patch.patch patches/soc_workshop_uboot_patch_2.patch
LINUX_BRANCH ?= socfpga-3.10-ltsi
UBOOT_PATCHES = $(sort $(wildcard patches/u-boot/*.patch))
LINUX_PATCHES = $(sort $(wildcard patches/$(LINUX_BRANCH)/*.patch))
DTS_COMMON = board_info/hps_common_board_info.xml
DTS_BOARD_INFOS = $(wildcard board_info/board_info_*.xml)


# Board revisions
REVISION_LIST = $(patsubst create_ghrd_quartus_%,%,$(basename $(notdir $(PROJECT_ASSIGN_SCRIPTS))))

QUARTUS_DEFAULT_REVISION_FILE = \
        $(if \
        $(filter create_ghrd_quartus_$(PROJECT_NAME).tcl,$(notdir $(PROJECT_ASSIGN_SCRIPTS))), \
        create_ghrd_quartus_$(PROJECT_NAME).tcl, \
        $(firstword $(PROJECT_ASSIGN_SCRIPTS)))

QUARTUS_DEFAULT_REVISION = $(patsubst create_ghrd_quartus_%, \
        %, \
        $(basename $(notdir $(QUARTUS_DEFAULT_REVISION_FILE))))

SCRIPT_DIR = utils

# Project specific settings
PROJECT_NAME = soc_workshop_system
QSYS_BASE_NAME = soc_system
TOP_LEVEL_ENTITY = ghrd_top

QSYS_HPS_INST_NAME = hps_0


# AR_FILTER_OUT := downloads

# initial save file list
AR_REGEX += ip readme.txt mks                                         
AR_REGEX += scripts 
AR_REGEX += patches 
AR_REGEX += $(SCRIPT_DIR) 
AR_REGEX += board_info
AR_REGEX += hdl_src
AR_REGEX += utils
AR_REGEX += boot.script
AR_REGEX += buildroot.defconfig

################################################
.PHONY: default
default: help
################################################

################################################
.PHONY: all
all: sd-fat

################################################
# DEPS
                                                                          
define create_deps
CREATE_PROJECT_STAMP_$1 := $(call get_stamp_target,$1.create_project)

CREATE_PROJECT_DEPS_$1 := scripts/create_ghrd_quartus_$1.tcl | logs

QUARTUS_STAMP_$1 := $(call get_stamp_target,$1.quartus)

PRELOADER_GEN_STAMP_$1 := $(call get_stamp_target,$1.preloader_gen)
PRELOADER_FIXUP_STAMP_$1 := $(call get_stamp_target,$1.preloader_fixup)
PRELOADER_STAMP_$1 := $(call get_stamp_target,$1.preloader)

UBOOT_STAMP_$1 := $(call get_stamp_target,$1.uboot)

DTS_STAMP_$1 := $(call get_stamp_target,$1.dts)
DTB_STAMP_$1 := $(call get_stamp_target,$1.dtb)

QSYS_STAMP_$1 := $(call get_stamp_target,$1.qsys_compile)
QSYS_GEN_STAMP_$1 := $(call get_stamp_target,$1.qsys_gen)
QSYS_ADD_ALL_COMP_STAMP_$1 := $(call get_stamp_target,$1.qsys_add_all_comp)
#QSYS_ADD_COMP_STAMP_$1 := $(foreach t,$(QSYS_ADD_COMP_TCLS),$(call get_stamp_target,$1.$t))
QSYS_RUN_ADD_COMPS_$1 = $(foreach t,$(QSYS_ADD_COMP_TCLS),$(call get_stamp_target,$1.$(notdir $t)))

QSYS_PIN_ASSIGNMENTS_STAMP_$1 := $$(call get_stamp_target,$1.quartus_pin_assignments)

QUARTUS_DEPS_$1 += $$(QUARTUS_PROJECT_STAMP_$1) $(QUARTUS_HDL_SOURCE) $(QUARTUS_MISC_SOURCE)
QUARTUS_DEPS_$1 += $$(CREATE_PROJECT_STAMP_$1)
QUARTUS_DEPS_$1 += $$(QSYS_PIN_ASSIGNMENTS_STAMP_$1) $$(QSYS_STAMP_$1)

PRELOADER_GEN_DEPS_$1 += $$(QUARTUS_STAMP_$1)
PRELOADER_FIXUP_DEPS_$1 += $$(PRELOADER_GEN_STAMP_$1)
PRELOADER_DEPS_$1 += $$(PRELOADER_FIXUP_STAMP_$1)

# QSYS_DEPS_$1 := $$(QSYS_GEN_STAMP_$1)
QSYS_DEPS_$1 += $1/$(QSYS_BASE_NAME).qsys $1/addon_components.ipx
QSYS_GEN_DEPS_$1 += $$(CREATE_PROJECT_STAMP_$1)
# QSYS_GEN_DEPS_$1 += scripts/create_ghrd_qsys.tcl scripts/devkit_hps_configurations.tcl
QSYS_GEN_DEPS_$1 += scripts/create_ghrd_qsys_$1.tcl scripts/qsys_default_components.tcl
QSYS_GEN_DEPS_$1 += $(QSYS_ADD_COMP_TCLS)
QSYS_GEN_DEPS_$1 += $1/addon_components.ipx

#only support one custom board xml
#DTS_BOARDINFO_$1 := $(firstword $(filter $1, $(DTS_BOARD_INFOS)))
DTS_BOARDINFO_$1 := board_info/board_info_$1.xml

DTS_DEPS_$1 += $$(DTS_BOARDINFO_$1) $(DTS_COMMON) $$(QSYS_STAMP_$1)
DTB_DEPS_$1 += $$(DTS_BOARDINFO_$1) $(DTS_COMMON) $$(QSYS_STAMP_$1)

QUARTUS_QPF_$1 := $1/$1.qpf
QUARTUS_QSF_$1 := $1/$1.qsf
QUARTUS_SOF_$1 := $1/output_files/$1.sof
QUARTUS_RBF_$1 := $1/output_files/$1.rbf
QUARTUS_JDI_$1 := $1/output_files/$1.jdi

QSYS_FILE_$1 := $1/$(QSYS_BASE_NAME).qsys
QSYS_SOPCINFO_$1 := $1/$(QSYS_BASE_NAME).sopcinfo

DEVICE_TREE_SOURCE_$1 := $1/$(QSYS_BASE_NAME).dts
DEVICE_TREE_BLOB_$1 := $1/$(QSYS_BASE_NAME).dtb

#QSYS_SOPCINFO_$1 := $(patsubst $1/%.qsys,$1/%.sopcinfo,$$(QSYS_FILE_$1))
#DEVICE_TREE_SOURCE_$1 := $(patsubst $1/%.sopcinfo,$1/%.dts,$$(QSYS_SOPCINFO_$1))
#DEVICE_TREE_BLOB_$1 := $(patsubst $1/%.sopcinfo,$1/%.dtb,$$(QSYS_SOPCINFO_$1))

AR_FILES += $$(QUARTUS_RBF_$1) $$(QUARTUS_SOF_$1)	
AR_FILES += $$(QSYS_SOPCINFO_$1) $$(QSYS_FILE_$1)

AR_REGEX += $1/$(QSYS_BASE_NAME)/*.svd

AR_FILES += $$(DEVICE_TREE_SOURCE_$1)
AR_FILES += $$(DEVICE_TREE_BLOB_$1)

AR_FILES += $1/preloader/uboot-socfpga/u-boot.img
AR_FILES += $1/preloader/preloader-mkpimage.bin

AR_FILES += $1/u-boot.img
AR_FILES += $1/preloader-mkpimage.bin
AR_FILES += $1/boot.script $1/u-boot.scr

ALL_DEPS_$1 += $$(QUARTUS_RBF_$1) $$(QUARTUS_SOF_$1) $$(QUARTUS_JDI_$1)
ALL_DEPS_$1 += $$(DEVICE_TREE_SOURCE_$1) $$(DEVICE_TREE_BLOB_$1)
ALL_DEPS_$1 += $1/u-boot.img $1/preloader-mkpimage.bin
ALL_DEPS_$1 += $$(QUARTUS_JDI_$1) $$(QSYS_SOPCINFO_$1) $$(QSYS_FILE_$1)
ALL_DEPS_$1 += $1/hps_isw_handoff $1/$1.qpf $1/$1.qsf

#SD_FAT_$1 += $$(ALL_DEPS_$1)
SD_FAT_$1 += $$(QUARTUS_RBF_$1) $$(QUARTUS_SOF_$1)
SD_FAT_$1 += $$(DEVICE_TREE_SOURCE_$1) $$(DEVICE_TREE_BLOB_$1)
SD_FAT_$1 += $1/u-boot.img $1/preloader-mkpimage.bin
SD_FAT_$1 += boot.script u-boot.scr

.PHONY:$1.all
$1.all: $$(ALL_DEPS_$1)
HELP_TARGETS += $1.all
$1.all.HELP := Build Quartus / preloader / uboot / devicetree / boot scripts for $1 board

endef
$(foreach r,$(REVISION_LIST),$(eval $(call create_deps,$r)))

AR_FILES += boot.script u-boot.scr

include mks/qsys.mk mks/quartus.mk mks/preloader_uboot.mk mks/devicetree.mk 
include mks/bootscript.mk 

################################################


################################################

SD_FAT_TGZ := sd_fat.tar.gz

SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$(SD_FAT_$r))
SD_FAT_TGZ_DEPS += boot.script u-boot.scr
#SD_FAT_TGZ_DEPS += hdl_src
#SD_FAT_TGZ_DEPS += board_info
#SD_FAT_TGZ_DEPS += ip

$(SD_FAT_TGZ): $(SD_FAT_TGZ_DEPS)
	@$(RM) $@
	@$(MKDIR) $(@D)
	$(TAR) -czf $@ $^

QUARTUS_OUT_TGZ := quartus_out.tar.gz 
QUARTUS_OUT_TGZ_DEPS += $(ALL_QUARTUS_RBF) $(ALL_QUARTUS_SOF)

$(QUARTUS_OUT_TGZ): $(QUARTUS_OUT_TGZ_DEPS)
	@$(RM) $@
	@$(MKDIR) $(@D)
	$(TAR) -czf $@ $^	
	
HELP_TARGETS += sd-fat
sd-fat.HELP := Generate tar file with contents for sdcard fat partition	
	
.PHONY: sd-fat
sd-fat: $(SD_FAT_TGZ)

AR_FILES += $(wildcard $(SD_FAT_TGZ))

SCRUB_CLEAN_FILES += $(SD_FAT_TGZ)
SCRUB_CLEAN_FILES += u-boot.scr

################################################


################################################
# Clean-up and Archive

AR_TIMESTAMP := $(if $(SOCEDS_VERSION),$(subst .,_,$(SOCEDS_VERSION))_)$(subst $(SPACE),,$(shell $(DATE) +%m%d%Y_%k%M%S))

AR_DIR := tgz
AR_FILE := $(AR_DIR)/soc_workshop_$(AR_TIMESTAMP).tar.gz

AR_FILES += $(filter-out $(AR_FILTER_OUT),$(wildcard $(AR_REGEX)))

CLEAN_FILES += $(filter-out $(AR_DIR) $(AR_FILES),$(wildcard *))

HELP_TARGETS += tgz
tgz.HELP := Create a tarball with the barebones source files that comprise this design

.PHONY: tarball tgz
tarball tgz: $(AR_FILE)

$(AR_FILE):
	@$(MKDIR) $(@D)
	@$(if $(wildcard $(@D)/*.tar.gz),$(MKDIR) $(@D)/.archive;$(MV) $(@D)/*.tar.gz $(@D)/.archive)
	@$(ECHO) "Generating $@..."
	@$(TAR) -czf $@ $(wildcard $(AR_FILES))

SCRUB_CLEAN_FILES += $(CLEAN_FILES)

HELP_TARGETS += scrub_clean
scrub_clean.HELP := Restore design to its barebones state

.PHONY: scrub scrub_clean
scrub scrub_clean:
	$(if $(strip $(wildcard $(SCRUB_CLEAN_FILES))),$(RM) $(wildcard $(SCRUB_CLEAN_FILES)),@$(ECHO) "You're already as clean as it gets!")

.PHONY: test_scrub_clean
test_scrub_clean:
	$(if $(strip $(wildcard $(SCRUB_CLEAN_FILES))),$(ECHO) $(wildcard $(SCRUB_CLEAN_FILES)),@$(ECHO) "You're already as clean as it gets!")

.PHONY: tgz_scrub_clean
tgz_scrub_clean:
	$(FIND) $(SOFTWARE_DIR) \( -name '*.o' -o -name '.depend*' -o -name '*.d' -o -name '*.dep' \) -delete || true
	$(MAKE) tgz AR_FILE=$(AR_FILE)
	$(MAKE) -s scrub_clean
	$(TAR) -xzf $(AR_FILE)

.PHONY: clean
clean:
	@$(ECHO) "Cleaning stamp files (which will trigger rebuild)"
	@$(RM) $(get_stamp_dir)
	@$(ECHO) " TIP: Use 'make scrub_clean' to get a deeper clean"

################################################


################################################

logs:
	$(MKDIR) logs

################################################
# Utils


################################################
# Help system

.PHONY: help
help: help-init help-targets help-revision-target help-fini

.PHONY: help-revisions
help-revisions: help-revisions-init help-revisions-list help-revisions-fini help-revision-target

.PHONY: help-revs
help-revs: help-revisions-init help-revisions-list help-revisions-fini help-revision-target-short


HELP_TARGETS_X := $(patsubst %,help-%,$(sort $(HELP_TARGETS)))

HELP_TARGET_REVISION_X := $(foreach r,$(REVISION_LIST),$(patsubst %,help_rev-%,$(sort $(HELP_TARGETS_$r))))

HELP_TARGET_REVISION_SHORT_X := $(sort $(patsubst $(firstword $(REVISION_LIST)).%,help_rev-REVISIONNAME.%,$(filter-out $(firstword $(REVISION_LIST)),$(HELP_TARGETS_$(firstword $(REVISION_LIST))))))

$(foreach h,$(filter-out $(firstword $(REVISION_LIST)),$(HELP_TARGETS_$(firstword $(REVISION_LIST)))),$(eval $(patsubst %-$(firstword $(REVISION_LIST)),%-REVISIONNAME,$h).HELP := $(subst $(firstword $(REVISION_LIST)),REVISIONNAME,$($h.HELP)))) 

HELP_REVISION_LIST := $(patsubst %,rev_list-%,$(sort $(REVISION_LIST)))

#cheat, put help at the end
HELP_TARGETS_X += help-help-revisions
help-revisions.HELP := Displays Revision specific Target Help

HELP_TARGETS_X += help-help-revs
help-revs.HELP := Displays Short Revision specific Target Help


HELP_TARGETS_X += help-help
help.HELP := Displays this info (i.e. the available targets)


.PHONY: $(HELP_TARGETS_X)
help-targets: $(HELP_TARGETS_X)
$(HELP_TARGETS_X): help-%:
	@$(ECHO) "*********************"
	@$(ECHO) "* Target: $*"
	@$(ECHO) "*   $($*.HELP)"

.PHONY: help-init
help-init:
	@$(ECHO) "*****************************************"
	@$(ECHO) "*                                       *"
	@$(ECHO) "* Manage QuartusII/QSys design          *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*     Copyright (c) 2014                *"
	@$(ECHO) "*     All Rights Reserved               *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*****************************************"
	@$(ECHO) ""

.PHONY: help-revisions-init
help-revisions-init:
	@$(ECHO) ""
	@$(ECHO) "*****************************************"
	@$(ECHO) "*                                       *"
	@$(ECHO) "* Revision specific Targets             *"
	@$(ECHO) "*    target-REVISIONNAME                *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*    Available Revisions:               *"
	

.PHONY: $(HELP_REVISION_LIST)
help-revisions-list: $(HELP_REVISION_LIST)
$(HELP_REVISION_LIST): rev_list-%: 
	@$(ECHO) "*    -> $*"

.PHONY: help-revisions-fini
help-revisions-fini:
	@$(ECHO) "*                                       *"
	@$(ECHO) "*****************************************"
	@$(ECHO) ""

.PHONY: $(HELP_TARGET_REVISION_X)
.PHONY: $(HELP_TARGET_REVISION_SHORT_X)
help-revision-target: $(HELP_TARGET_REVISION_X)
help-revision-target-short: $(HELP_TARGET_REVISION_SHORT_X)
$(HELP_TARGET_REVISION_X) $(HELP_TARGET_REVISION_SHORT_X): help_rev-%:
	@$(ECHO) "*********************"
	@$(ECHO) "* Target: $*"
	@$(ECHO) "*   $($*.HELP)"
	
.PHONY: help-fini
help-fini:
	@$(ECHO) "*********************"

################################################
