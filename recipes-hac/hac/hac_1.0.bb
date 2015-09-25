DESCRIPTION = "Target Communication Framework"
HOMEPAGE = "http://wiki.eclipse.org/TCF"
BUGTRACKER = "https://bugs.eclipse.org/bugs/"

LICENSE = "EPL-1.0 | EDL-1.0"
LIC_FILES_CHKSUM = "file://examples/device/Makefile;md5=1633bbc4f9d39da6e84fdd52bf5d9970"

SRCREV = "b2be25db62368bbbd964b23cf4604059a758e0f5"

PV = "wb_vadk+git${SRCPV}"
PR = "r1"

SRC_URI = "git://git.wrs.com/git/projects/tcf-c-core.git;branch=wb_vadk \
	   file://hac.init \
	   file://hac.service \
	   file://registerTarget \
	   file://HelixUtils.pm \
	   file://sdkName.txt \
	   file://sdkVersion.txt \
	   "

DEPENDS = "util-linux openssl"

RDEPENDS_${PV} = "perl"

S = "${WORKDIR}/git"

LSRCPATH = "${S}/examples/device"

inherit update-rc.d systemd

SYSTEMD_SERVICE_${PN} = "hac.service"

INITSCRIPT_NAME = "hac"
INITSCRIPT_PARAMS = "start 99 3 5 . stop 20 0 1 2 6 ."

# mangling needed for make
MAKE_ARCH = "`echo ${TARGET_ARCH} | sed s,i.86,i686,`"
MAKE_OS = "`echo ${TARGET_OS} | sed s,^linux.*,GNU/Linux,`"

EXTRA_OEMAKE = "MACHINE=${MAKE_ARCH} OPSYS=${MAKE_OS} 'CC=${CC}' 'AR=${AR}' 'Conf=Release'"

FILES_${PN} += "/usr/local"
FILES_${PN} += "/etc/default"

do_compile() {
	export CONFIGURE_FLAGS="--host=${MAKE_ARCH}-gnu-linux"
	oe_runmake -C ${LSRCPATH}
}

do_install() {
	install -d ${D}${sbindir}
	oe_runmake -C ${LSRCPATH} install INSTALLDIR=${D}${sbindir}
	install -d ${D}${sysconfdir}
	install -d ${D}${sysconfdir}/init.d/
	install -m 0755 ${WORKDIR}/hac.init ${D}${sysconfdir}/init.d/hac
	install -m 0755 ${WORKDIR}/registerTarget ${D}${sbindir}/registerTarget
	install -d ${D}/usr/local/lib/site_perl/
	install -m 0644 ${WORKDIR}/HelixUtils.pm ${D}/usr/local/lib/site_perl
        install -d ${D}/etc/default/
        install -m 0644 ${WORKDIR}/sdkVersion.txt ${D}/etc/default
        install -m 0644 ${WORKDIR}/sdkName.txt ${D}/etc/default

	# systemd
	install -d ${D}${sysconfdir}/hac/
	install -m 0755 ${WORKDIR}/hac.init ${D}${sysconfdir}/hac
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${WORKDIR}/hac.service ${D}${systemd_unitdir}/system

}

