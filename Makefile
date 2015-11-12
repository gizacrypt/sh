prefix=/usr/local

giza:
	echo '#!/bin/sh' > giza
	echo 'gpg --verify "$$0" 2>/dev/null || gpg --verify "$$0" || exit $$?' >> giza
	echo 'tee >/dev/null <<true' >> giza
	gpg --clearsign < giza.sh >> giza
	chmod +x giza

install: giza
	install -m 0755 giza $(prefix)/bin/giza
	install -m 0755 giza-validate.sh $(prefix)/bin/giza-validate
	install -m 0644 man1/giza.1 $(prefix)/share/man/man1/giza.1

uninstall:
	rm $(prefix)/bin/giza
	rm $(prefix)/bin/giza-validate
	rm $(prefix)/share/man/man1/giza.1

clean:
	rm giza
