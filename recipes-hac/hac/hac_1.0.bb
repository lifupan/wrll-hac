DESCRIPTION = "Target Communication Framework"
HOMEPAGE = "http://wiki.eclipse.org/TCF"
BUGTRACKER = "https://bugs.eclipse.org/bugs/"

LICENSE = "EPL-1.0 | EDL-1.0"
LIC_FILES_CHKSUM = "file://Makefile;md5=5c38456fe56dace2d12005b5a34f2177"

SRCREV = "a2c2365a955f327026d41a187599a2687fed0002"
PV = "wb_vadk+git${SRCPV}"
PR = "r1"

FILES_${PN} = "/media /media/card ${sbindir}/device ${sysconfdir}/init.d/device ${sysconfdir}/fstab ${sysconfdir}/securetty"

SRC_URI = "git://git.wrs.com/git/projects/tcf-c-core.git;branch=wb_vadk \
	   file://device.init \
	   file://fstab \
	   file://securetty \
	   "

dirs = "/media \
	/media/card"

DEPENDS = "util-linux openssl"
RDEPENDS_${PN} = "bash"

S = "${WORKDIR}/git/examples/device"

inherit update-rc.d

INITSCRIPT_NAME = "device"
INITSCRIPT_PARAMS = "start 99 3 5 . stop 20 0 1 2 6 ."

# mangling needed for make
MAKE_ARCH = "`echo ${TARGET_ARCH} | sed s,i.86,i686,`"
MAKE_OS = "`echo ${TARGET_OS} | sed s,^linux.*,GNU/Linux,`"

EXTRA_OEMAKE = "MACHINE=${MAKE_ARCH} OPSYS=${MAKE_OS} 'CC=${CC}' 'AR=${AR}' 'Conf=Release'"

do_compile() {
	oe_runmake
}

do_install() {
  	for d in ${dirs}; do
	    install -m 0755 -d ${D}$d
	done
	install -d ${D}${sbindir}
	oe_runmake install INSTALLDIR=${D}${sbindir}
	install -d ${D}${sysconfdir}
	install -d ${D}${sysconfdir}/init.d/
	install -m 0755 ${WORKDIR}/device.init ${D}${sysconfdir}/init.d/device
	install -m 0755 ${WORKDIR}/fstab ${D}${sysconfdir}/fstab
	install -m 0755 ${WORKDIR}/securetty ${D}${sysconfdir}/securetty
}

