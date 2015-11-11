prefix=/usr/local

giza:
	echo '#!/bin/sh' > giza
	echo 'gpg --verify "$$0" 2>/dev/null || gpg --verify "$$0" || exit $$?' >> giza
	echo 'tee >/dev/null <<true' >> giza
	gpg --clearsign < giza.sh >> giza
	chmod +x giza

install: giza
	install -m 0755 giza $(prefix)/bin
	install -m 0644 man1/* $(prefix)/share/man/man1
