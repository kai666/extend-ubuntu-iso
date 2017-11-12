PACKAGE=	extend-ubuntu-iso
VERSION=	0.1

PREFIX=		/usr

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
	install -m 0755 -d package${PREFIX}/bin
	install -m 0755 extend-ubuntu-iso.bash package${PREFIX}/bin/extend-ubuntu-iso
	install -m 0755 -d package${PREFIX}/share/extend-ubuntu-iso
	install -m 0755 chroot-before.example.bash package${PREFIX}/share/extend-ubuntu-iso/
	install -m 0755 -d package${PREFIX}/share/doc/extend-ubuntu-iso
	install -m 0644 LICENSE package${PREFIX}/share/doc/extend-ubuntu-iso/copyright
	gzip --best -c changelog > package${PREFIX}/share/doc/extend-ubuntu-iso/changelog.gz
	chmod 0644 package${PREFIX}/share/doc/extend-ubuntu-iso/changelog.gz
	install -m 0644 gitref package${PREFIX}/share/extend-ubuntu-iso/
	fakeroot dpkg-deb --build package
	mv package.deb ${PACKAGE}_${VERSION}.deb

%.bash.syntax: %.bash
	bash -n $< && date > $@

