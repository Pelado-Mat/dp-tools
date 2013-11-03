VERSION=1.0
ALL_SOURCES=device-replicator.pl mcfsend.pl mcfreceive.pl pool-replicator.pl dpha-preamble.tex

dpha-$(VERSION).zip: dpha.pdf mcfsend.pl mcfreceive.pl pool-replicator.pl device-replicator.pl
	mkdir -p dpha-$(VERSION)
	cp dpha.pdf dpha-$(VERSION)/
	cp mcfsend.pl  dpha-$(VERSION)/
	cp mcfreceive.pl  dpha-$(VERSION)/
	cp pool-replicator.pl  dpha-$(VERSION)/
	cp device-replicator.pl  dpha-$(VERSION)/
	zip -9 -r dpha-$(VERSION).zip dpha-$(VERSION)

dpha.pdf: dpha.tex
	pdflatex dpha.tex
	pdflatex dpha.tex

dpha.tex: $(ALL_SOURCES)
	pod2latex -prefile dpha-preamble.tex -out dpha.tex -full -modify $(ALL_SOURCES)