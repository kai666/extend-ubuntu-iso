PACKAGE=	extend-ubuntu-iso
VERSION=	0.1

PREFIX=		/usr
INSTALL=	/usr/bin/install
INSTALL_SCRIPT=	${INSTALL} -m 0755
INSTALL_DATA=	${INSTALL} -m 0644
INSTALL_DIR=	${INSTALL} -m 0755 -d

SRC=		extend-ubuntu-iso.bash chroot-before.example.bash
SYNTAX=		$(addsuffix .syntax, ${SRC})

.PHONY: all clean distclean deb appendchangelog

all:	${SYNTAX} gitref

clean:
	rm -f ${SYNTAX}
	rm -rf package/usr
	rm -f *.deb
	rm -f gitref

distclean: clean

gitref: .git
	git describe --abbrev=8 --dirty --always --tags > $@
	date >> $@

appendchangelog:
	CHANGELOG=changelog dch -a

deb:
	${INSTALL_DIR} package${PREFIX}/bin
	${INSTALL_SCRIPT} extend-ubuntu-iso.bash package${PREFIX}/bin/extend-ubuntu-iso
	${INSTALL_DIR} package${PREFIX}/share/extend-ubuntu-iso
	${INSTALL_SCRIPT} chroot-before.example.bash package${PREFIX}/share/extend-ubuntu-iso/
	${INSTALL_DIR} package${PREFIX}/share/doc/extend-ubuntu-iso
	${INSTALL_DATA} LICENSE package${PREFIX}/share/doc/extend-ubuntu-iso/copyright
	gzip --best -c changelog > package${PREFIX}/share/doc/extend-ubuntu-iso/changelog.gz
	chmod 0644 package${PREFIX}/share/doc/extend-ubuntu-iso/changelog.gz
	${INSTALL_DATA} gitref package${PREFIX}/share/extend-ubuntu-iso/
	fakeroot dpkg-deb --build package
	mv package.deb ${PACKAGE}_${VERSION}.deb
	lintian ${PACKAGE}_${VERSION}.deb

%.bash.syntax: %.bash
	bash -n $< && date > $@

