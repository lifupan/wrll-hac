DESCRIPTION = "Target Communication Framework"
HOMEPAGE = "http://wiki.eclipse.org/TCF"
BUGTRACKER = "https://bugs.eclipse.org/bugs/"

LICENSE = "EPL-1.0 | EDL-1.0"
LIC_FILES_CHKSUM = "file://Makefile;md5=1633bbc4f9d39da6e84fdd52bf5d9970"

SRCREV = "0f3649a6511af2b45cbd4552f93e31561d8a2ef7"

PV = "wb_vadk+git${SRCPV}"
PR = "r1"

SRC_URI = "git://git.wrs.com/git/projects/tcf-c-core.git;branch=wb_vadk \
	   file://securetty \
	   file://hac.init \
	   file://hac.service \
	   "

DEPENDS = "util-linux openssl"
RDEPENDS_${PN} = "bash inetutils-inetd"

S = "${WORKDIR}/git/examples/device"

inherit update-rc.d systemd

SYSTEMD_SERVICE_${PN} = "hac.service"

INITSCRIPT_NAME = "hac"
INITSCRIPT_PARAMS = "start 99 3 5 . stop 20 0 1 2 6 ."

# mangling needed for make
MAKE_ARCH = "`echo ${TARGET_ARCH} | sed s,i.86,i686,`"
MAKE_OS = "`echo ${TARGET_OS} | sed s,^linux.*,GNU/Linux,`"

EXTRA_OEMAKE = "MACHINE=${MAKE_ARCH} OPSYS=${MAKE_OS} 'CC=${CC}' 'AR=${AR}' 'Conf=Release'"

do_compile() {
	export CONFIGURE_FLAGS="--host=${MAKE_ARCH}-gnu-linux"
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
	install -m 0755 ${WORKDIR}/hac.init ${D}${sysconfdir}/init.d/hac

	# systemd
	install -d ${D}${sysconfdir}/hac/
	install -m 0755 ${WORKDIR}/hac.init ${D}${sysconfdir}/hac
	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${WORKDIR}/hac.service ${D}${systemd_unitdir}/system

}

