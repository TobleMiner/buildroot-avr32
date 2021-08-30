################################################################################
#
# binutils
#
################################################################################

# Version is set when using buildroot toolchain.
# If not, we do like other packages
BINUTILS_VERSION = $(call qstrip,$(BR2_BINUTILS_VERSION))
ifeq ($(BINUTILS_VERSION),)
ifeq ($(BR2_avr32),y)
# avr32 uses a special version
BINUTILS_VERSION = 2.18-avr32-1.0.1
else
BINUTILS_VERSION = 2.22
endif
endif

ifeq ($(BINUTILS_VERSION),2.18-avr32-1.0.1)
BINUTILS_SITE = ftp://www.at91.com/pub/buildroot
endif
ifeq ($(BINUTILS_VERSION),2.22-avr32)
BINUTILS_SOURCE = binutils-2.22.tar.bz2
BINUTILS_AUTORECONF = YES
define BINUTILS_AVR32_PRE_CONFIGURE
	# Reconfigure binutils
	$(Q)cd $($(PKG)_SRCDIR); $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE); $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	$(Q)cd $($(PKG)_SRCDIR)/binutils; $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE) --add-missing; $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	# Reconfigure ld
	$(Q)cd $($(PKG)_SRCDIR)/ld; $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE); $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	# Reconfigure opcodes
	$(Q)cd $($(PKG)_SRCDIR)/opcodes; $(ACLOCAL); $(AUTOCONF); $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	# Reconfigure gas, needs automake documentation fixup
	$(Q)cd $($(PKG)_SRCDIR)/gas; $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE) --add-missing; $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	# Reconfigure bfd, needs automake documentation fixup
	$(Q)cd $($(PKG)_SRCDIR)/bfd; $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE) --add-missing; $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
	# Reconfigure gprof
	$(Q)cd $($(PKG)_SRCDIR)/gprof; $(ACLOCAL); $(AUTOCONF); $(AUTOMAKE); $($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
endef
#HOST_BINUTILS_POST_PATCH_HOOKS += BINUTILS_AVR32_PRE_CONFIGURE
define BINUTILS_AVR32_POST_CONFIGURE
	$(HOST_MAKE_ENV) $($(PKG)_MAKE_ENV) $($(PKG)_MAKE) $($(PKG)_MAKE_OPTS) -C $($(PKG)_SRCDIR) configure-host && \
	$(RM) -f $($(PKG)_SRCDIR)/bfd/bfd.h $($(PKG)_SRCDIR)/bfd/doc/bfd.h && \
	$(HOST_MAKE_ENV) $($(PKG)_MAKE_ENV) $($(PKG)_MAKE) $($(PKG)_MAKE_OPTS) -C $($(PKG)_SRCDIR)/bfd headers && \
	$(HOST_MAKE_ENV) $($(PKG)_MAKE_ENV) $($(PKG)_MAKE) $($(PKG)_MAKE_OPTS) -C $($(PKG)_SRCDIR)/bfd bfd.h
endef
#HOST_BINUTILS_POST_CONFIGURE_HOOKS += BINUTILS_AVR32_POST_CONFIGURE
define BINUTILS_AVR32_PRE_BUILD
	# Remove stale bfd-in2.h
#	$(RM) -f $($(PKG)_SRCDIR)/bfd/bfd-in2.h
endef
#HOST_BINUTILS_PRE_BUILD_HOOKS += BINUTILS_AVR32_PRE_BUILD
endif
ifeq ($(BINUTILS_VERSION),2.20.1-avr32)
BINUTILS_SOURCE = binutils-2.20.1.tar.bz2
BINUTILS_AUTORECONF = YES
endif
ifeq ($(BR2_arc),y)
BINUTILS_SITE = $(call github,foss-for-synopsys-dwc-arc-processors,binutils-gdb,$(BINUTILS_VERSION))
BINUTILS_SOURCE = binutils-$(BINUTILS_VERSION).tar.gz
BINUTILS_FROM_GIT = y
endif
BINUTILS_SITE ?= $(BR2_GNU_MIRROR)/binutils
BINUTILS_SOURCE ?= binutils-$(BINUTILS_VERSION).tar.bz2
BINUTILS_EXTRA_CONFIG_OPTIONS = $(call qstrip,$(BR2_BINUTILS_EXTRA_CONFIG_OPTIONS))
BINUTILS_INSTALL_STAGING = YES
BINUTILS_DEPENDENCIES = $(if $(BR2_NEEDS_GETTEXT_IF_LOCALE),gettext)
HOST_BINUTILS_DEPENDENCIES =
BINUTILS_LICENSE = GPLv3+, libiberty LGPLv2.1+
BINUTILS_LICENSE_FILES = COPYING3 COPYING.LIB

ifeq ($(BINUTILS_FROM_GIT),y)
BINUTILS_DEPENDENCIES += host-texinfo host-flex host-bison
HOST_BINUTILS_DEPENDENCIES += host-texinfo host-flex host-bison
endif

# When binutils sources are fetched from the binutils-gdb repository,
# they also contain the gdb sources, but gdb shouldn't be built, so we
# disable it.
BINUTILS_DISABLE_GDB_CONF_OPTS = \
	--disable-sim \
	--disable-gdb

# We need to specify host & target to avoid breaking ARM EABI
BINUTILS_CONF_OPTS = \
	--disable-multilib \
	--disable-werror \
	--host=$(GNU_TARGET_NAME) \
	--target=$(GNU_TARGET_NAME) \
	--enable-install-libiberty \
	--srcdir=$($(PKG)_SRCDIR) \
	$(BINUTILS_DISABLE_GDB_CONF_OPTS) \
	$(BINUTILS_EXTRA_CONFIG_OPTIONS)

# Don't build documentation. It takes up extra space / build time,
# and sometimes needs specific makeinfo versions to work
BINUTILS_CONF_ENV += ac_cv_prog_MAKEINFO=missing
HOST_BINUTILS_CONF_ENV += ac_cv_prog_MAKEINFO=missing

# Install binutils after busybox to prefer full-blown utilities
ifeq ($(BR2_PACKAGE_BUSYBOX),y)
BINUTILS_DEPENDENCIES += busybox
endif

# "host" binutils should actually be "cross"
# We just keep the convention of "host utility" for now
HOST_BINUTILS_CONF_OPTS = \
	--disable-multilib \
	--disable-werror \
	--target=$(GNU_TARGET_NAME) \
	--disable-shared \
	--enable-static \
	--with-sysroot=$(STAGING_DIR) \
	--enable-poison-system-directories \
	$(BINUTILS_DISABLE_GDB_CONF_OPTS) \
	$(BINUTILS_EXTRA_CONFIG_OPTIONS)

# We just want libbfd, libiberty and libopcodes,
# not the full-blown binutils in staging
define BINUTILS_INSTALL_STAGING_CMDS
	$(MAKE) -C $(@D)/bfd DESTDIR=$(STAGING_DIR) install
	$(MAKE) -C $(@D)/opcodes DESTDIR=$(STAGING_DIR) install
	$(MAKE) -C $(@D)/libiberty DESTDIR=$(STAGING_DIR) install
endef

# If we don't want full binutils on target
ifneq ($(BR2_PACKAGE_BINUTILS_TARGET),y)
define BINUTILS_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/bfd DESTDIR=$(TARGET_DIR) install
	$(MAKE) -C $(@D)/libiberty DESTDIR=$(STAGING_DIR) install
endef
endif

XTENSA_CORE_NAME = $(call qstrip, $(BR2_XTENSA_CORE_NAME))
ifneq ($(XTENSA_CORE_NAME),)
define BINUTILS_XTENSA_PRE_PATCH
	tar xf $(BR2_XTENSA_OVERLAY_DIR)/xtensa_$(XTENSA_CORE_NAME).tar \
		-C $(@D) --strip-components=1 binutils
endef
BINUTILS_PRE_PATCH_HOOKS += BINUTILS_XTENSA_PRE_PATCH
HOST_BINUTILS_PRE_PATCH_HOOKS += BINUTILS_XTENSA_PRE_PATCH
endif

$(eval $(autotools-package))
$(eval $(host-autotools-package))
