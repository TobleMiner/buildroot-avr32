################################################################################
#
# Common variables for the gcc-initial and gcc-final packages.
#
################################################################################

#
# Version, site and source
#

GCC_VERSION = $(call qstrip,$(BR2_GCC_VERSION))

ifeq ($(findstring avr32,$(GCC_VERSION)),avr32)
GCC_SITE = ftp://www.at91.com/pub/buildroot
else ifeq ($(BR2_arc),y)
GCC_SITE = $(call github,foss-for-synopsys-dwc-arc-processors,gcc,$(GCC_VERSION))
GCC_SOURCE = gcc-$(GCC_VERSION).tar.gz
else
GCC_SITE = $(BR2_GNU_MIRROR:/=)/gcc/gcc-$(GCC_VERSION)
endif

GCC_SOURCE ?= gcc-$(GCC_VERSION).tar.bz2

#
# Xtensa special hook
#

define HOST_GCC_XTENSA_OVERLAY_EXTRACT
	tar xf $(BR2_XTENSA_OVERLAY_DIR)/xtensa_$(call qstrip,\
		$(BR2_XTENSA_CORE_NAME)).tar -C $(@D) --strip-components=1 gcc
endef

#
# Apply patches
#

ifeq ($(ARCH),powerpc)
ifneq ($(BR2_SOFT_FLOAT),)
define HOST_GCC_APPLY_POWERPC_PATCH
	$(APPLY_PATCHES) $(@D) package/gcc/$(GCC_VERSION) 1000-powerpc-link-with-math-lib.patch.conditional
endef
endif
endif

define HOST_GCC_APPLY_PATCHES
	if test -d package/gcc/$(GCC_VERSION); then \
	  $(APPLY_PATCHES) $(@D) package/gcc/$(GCC_VERSION) \*.patch ; \
	fi;
	$(HOST_GCC_APPLY_POWERPC_PATCH)
endef

#
# Custom extract command to save disk space
#

define HOST_GCC_EXTRACT_CMDS
	$(call suitable-extractor,$(GCC_SOURCE)) $(DL_DIR)/$(GCC_SOURCE) | \
		$(TAR) $(TAR_STRIP_COMPONENTS)=1 -C $(@D) \
		--exclude='libjava/*' \
		--exclude='libgo/*' \
		--exclude='gcc/testsuite/*' \
		--exclude='libstdc++-v3/testsuite/*' \
		$(TAR_OPTIONS) -
	mkdir -p $(@D)/libstdc++-v3/testsuite/
	echo "all:" > $(@D)/libstdc++-v3/testsuite/Makefile.in
	echo "install:" >> $(@D)/libstdc++-v3/testsuite/Makefile.in
endef

#
# Create 'build' directory and configure symlink
#

define HOST_GCC_CONFIGURE_SYMLINK
	mkdir -p $(@D)/build
	ln -sf ../configure $(@D)/build/configure
endef

#
# Common configuration options
#

HOST_GCC_COMMON_DEPENDENCIES = \
	host-binutils \
	host-gmp \
	host-mpfr \
	$(if $(BR2_BINFMT_FLAT),host-elf2flt)

HOST_GCC_COMMON_CONF_OPTS = \
	--target=$(GNU_TARGET_NAME) \
	--with-sysroot=$(STAGING_DIR) \
	--disable-__cxa_atexit \
	--with-gnu-ld \
	--disable-multilib \
	--with-gmp=$(HOST_DIR)/usr \
	--with-mpfr=$(HOST_DIR)/usr

# Stack protection needs libssp
ifneq ($(BR2_TOOLCHAIN_BUILDROOT_USE_SSP),y)
HOST_GCC_COMMON_CONF_OPTS += --disable-libssp
endif

# Don't build documentation. It takes up extra space / build time,
# and sometimes needs specific makeinfo versions to work
HOST_GCC_COMMON_CONF_ENV = \
	MAKEINFO=missing

# http://gcc.gnu.org/bugzilla/show_bug.cgi?id=43810
# Workaround until it's fixed in 4.5.4 or later
ifeq ($(ARCH),powerpc)
ifeq ($(findstring x4.5.,x$(GCC_VERSION)),x4.5.)
HOST_GCC_COMMON_CONF_OPTS += --disable-target-optspace
endif
else
HOST_GCC_COMMON_CONF_OPTS += --enable-target-optspace
endif

# libitm needs sparc V9+
ifeq ($(BR2_sparc_v8)$(BR2_sparc_leon3),y)
HOST_GCC_COMMON_CONF_OPTS += --disable-libitm
endif

# gcc 4.6.x quadmath requires wchar
ifneq ($(BR2_TOOLCHAIN_BUILDROOT_WCHAR),y)
HOST_GCC_COMMON_CONF_OPTS += --disable-libquadmath
endif

# libsanitizer requires wordexp, not in default uClibc config. Also
# doesn't build properly with musl.
ifeq ($(BR2_TOOLCHAIN_BUILDROOT_UCLIBC)$(BR2_TOOLCHAIN_BUILDROOT_MUSL),y)
HOST_GCC_COMMON_CONF_OPTS += --disable-libsanitizer
endif

ifeq ($(BR2_GCC_ENABLE_TLS),y)
HOST_GCC_COMMON_CONF_OPTS += --enable-tls
else
HOST_GCC_COMMON_CONF_OPTS += --disable-tls
endif

ifeq ($(BR2_GCC_ENABLE_LIBMUDFLAP),y)
HOST_GCC_COMMON_CONF_OPTS += --enable-libmudflap
else
HOST_GCC_COMMON_CONF_OPTS += --disable-libmudflap
endif

ifeq ($(BR2_PTHREADS_NONE),y)
HOST_GCC_COMMON_CONF_OPTS += \
	--disable-threads \
	--disable-libitm \
	--disable-libatomic
else
HOST_GCC_COMMON_CONF_OPTS += --enable-threads
endif

ifeq ($(BR2_GCC_NEEDS_MPC),y)
HOST_GCC_COMMON_DEPENDENCIES += host-mpc
HOST_GCC_COMMON_CONF_OPTS += --with-mpc=$(HOST_DIR)/usr
endif

ifeq ($(BR2_GCC_ENABLE_GRAPHITE),y)
HOST_GCC_COMMON_DEPENDENCIES += host-isl host-cloog
HOST_GCC_COMMON_CONF_OPTS += --with-isl=$(HOST_DIR)/usr --with-cloog=$(HOST_DIR)/usr
else
HOST_GCC_COMMON_CONF_OPTS += --without-isl --without-cloog
endif

ifeq ($(BR2_arc),y)
HOST_GCC_COMMON_DEPENDENCIES += host-flex host-bison
endif

ifeq ($(BR2_SOFT_FLOAT),y)
# only mips*-*-*, arm*-*-* and sparc*-*-* accept --with-float
# powerpc seems to be needing it as well
ifeq ($(BR2_arm)$(BR2_armeb)$(BR2_mips)$(BR2_mipsel)$(BR2_mips64)$(BR2_mips64el)$(BR2_powerpc)$(BR2_sparc),y)
HOST_GCC_COMMON_CONF_OPTS += --with-float=soft
endif
endif

ifeq ($(BR2_GCC_SUPPORTS_FINEGRAINEDMTUNE),y)
HOST_GCC_COMMON_CONF_OPTS += --disable-decimal-float
endif

# Determine arch/tune/abi/cpu options
ifneq ($(call qstrip,$(BR2_GCC_TARGET_ARCH)),)
HOST_GCC_COMMON_CONF_OPTS += --with-arch=$(BR2_GCC_TARGET_ARCH)
endif
ifneq ($(call qstrip,$(BR2_GCC_TARGET_ABI)),)
HOST_GCC_COMMON_CONF_OPTS += --with-abi=$(BR2_GCC_TARGET_ABI)
endif
# GCC doesn't support --with-cpu for bfin
ifeq ($(BR2_bfin),)
ifneq ($(call qstrip,$(BR2_GCC_TARGET_CPU)),)
ifneq ($(call qstrip,$(BR2_GCC_TARGET_CPU_REVISION)),)
HOST_GCC_COMMON_CONF_OPTS += --with-cpu=$(call qstrip,$(BR2_GCC_TARGET_CPU)-$(BR2_GCC_TARGET_CPU_REVISION))
else
HOST_GCC_COMMON_CONF_OPTS += --with-cpu=$(call qstrip,$(BR2_GCC_TARGET_CPU))
endif
endif
endif

GCC_TARGET_FPU = $(call qstrip,$(BR2_GCC_TARGET_FPU))
ifneq ($(GCC_TARGET_FPU),)
HOST_GCC_COMMON_CONF_OPTS += --with-fpu=$(GCC_TARGET_FPU)
endif

GCC_TARGET_FLOAT_ABI = $(call qstrip,$(BR2_GCC_TARGET_FLOAT_ABI))
ifneq ($(GCC_TARGET_FLOAT_ABI),)
HOST_GCC_COMMON_CONF_OPTS += --with-float=$(GCC_TARGET_FLOAT_ABI)
endif

GCC_TARGET_MODE = $(call qstrip,$(BR2_GCC_TARGET_MODE))
ifneq ($(GCC_TARGET_MODE),)
HOST_GCC_COMMON_CONF_OPTS += --with-mode=$(GCC_TARGET_MODE)
endif

# Branding works on >= 4.3
ifneq ($(findstring x4.2.,x$(GCC_VERSION)),x4.2.)
HOST_GCC_COMMON_CONF_OPTS += \
	--with-pkgversion="Buildroot $(BR2_VERSION_FULL)" \
	--with-bugurl="http://bugs.buildroot.net/"
endif

# Enable proper double/long double for SPE ABI
ifeq ($(BR2_powerpc_SPE),y)
HOST_GCC_COMMON_CONF_OPTS += \
	--enable-e500_double \
	--with-long-double-128
endif

include $(sort $(wildcard package/gcc/*/*.mk))
