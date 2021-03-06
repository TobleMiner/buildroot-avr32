################################################################################
#
# pcre
#
################################################################################

PCRE_VERSION = 8.36
PCRE_SITE = ftp://ftp.pcre.org/pub/pcre/
PCRE_LICENSE = BSD-3c
PCRE_LICENSE_FILES = LICENCE
PCRE_INSTALL_STAGING = YES
PCRE_CONFIG_SCRIPTS = pcre-config

ifneq ($(BR2_INSTALL_LIBSTDCPP),y)
# pcre will use the host g++ if a cross version isn't available
PCRE_CONF_OPTS = --disable-cpp
endif

PCRE_CONF_OPTS += --enable-pcre8
PCRE_CONF_OPTS += $(if $(BR2_PACKAGE_PCRE_16),--enable-pcre16,--disable-pcre16)
PCRE_CONF_OPTS += $(if $(BR2_PACKAGE_PCRE_32),--enable-pcre32,--disable-pcre32)
PCRE_CONF_OPTS += $(if $(BR2_PACKAGE_PCRE_UTF),--enable-utf,--disable-utf)
PCRE_CONF_OPTS += $(if $(BR2_PACKAGE_PCRE_UCP),--enable-unicode-properties,--disable-unicode-properties)

$(eval $(autotools-package))
$(eval $(host-autotools-package))
