webgostatus:
	go build -o webgostatus main.go

clean:
	webgostatus

install:
	mkdir -p $(DESTDIR)/usr/bin
	install -m 0755 webgostatus $(DESTDIR)/usr/bin/webgostatus
