VERSION=1.0.0
ALL_SOURCES=device-replicator.pl pool-replicator.pl dp-migration-preamble.tex dp-move-clients.pl mcf-all-media.pl mega-import.pl

dp-migration-$(VERSION).zip: dp-migration.pdf pool-replicator.pl device-replicator.pl dp-move-clients.pl mcf-all-media.pl mega-import.pl
	mkdir -p dp-migration-$(VERSION)
	cp dp-migration.pdf dp-migration-$(VERSION)/
	cp pool-replicator.pl  dp-migration-$(VERSION)/
	cp device-replicator.pl  dp-migration-$(VERSION)/
	cp dp-move-clients.pl dp-migration-$(VERSION)/
	cp mcf-all-media.pl dp-migration-$(VERSION)/
	cp mega-import.pl dp-migration-$(VERSION)/
	zip -9 -r dp-migration-$(VERSION).zip dp-migration-$(VERSION)

dp-migration.pdf: dp-migration.tex
	pdflatex dp-migration.tex
	pdflatex dp-migration.tex

dp-migration.tex: $(ALL_SOURCES)
	pod2latex -prefile dp-migration-preamble.tex -out dp-migration.tex -full -modify $(ALL_SOURCES)