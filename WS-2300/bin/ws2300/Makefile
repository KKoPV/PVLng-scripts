ME=$(shell sed -n '1s/ .*//p' ChangeLog.txt)
PACKAGE=$(shell echo "$(ME)" | sed 's/-[^-]*$$//')

PREFIX	?= /usr

.PHONY: binary
binary:

.PHONY: install
install: binary
	$(PYTHON) ./setup.py install $(SETUP_PY_FLAGS) --prefix=$(DESTDIR)$(PREFIX)
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cd $(DESTDIR)$(PREFIX)/bin && ln -s $$(find .. -name ws2300.py) ws2300
	install -m 0755 -d $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 0666 $(PACKAGE).1 $(DESTDIR)$(PREFIX)/share/man/man1/$(PACKAGE).1

.PHONY: clean
clean:
	rm -f *.pyc
	rm -rf $(RELEASE_DIR)
	$(PYTHON) ./setup.py clean --all

RELEASE_SOURCES = \
	ChangeLog.txt \
	Makefile \
	Makefile.release \
	memory_map_2300.txt \
	README.txt \
	setup.py \
	ws2300.1 \
	ws2300.default \
	ws2300.html \
	ws2300.init \
	ws2300.py \
	ws2300.spec

include Makefile.release

release-project-clean:: clean
