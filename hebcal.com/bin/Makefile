XMLDIR = ../dist
CSVDIR = ../dist
SEDROT = ../sedrot
DBDIR = ../hebcal
HOLIDAYS = ../holidays

all: sedrot holidays

holidays: $(HOLIDAYS)/purim.html $(DBDIR)/holidays.db

sedrot: $(SEDROT)/bereshit.html $(DBDIR)/sedrot.db

$(DBDIR)/sedrot.db: sedrot_db.pl $(XMLDIR)/aliyah.xml
	./sedrot_db.pl $(XMLDIR)/aliyah.xml $@

$(DBDIR)/holidays.db: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini /dev/null $@

$(SEDROT)/bereshit.html: calc_triennial.pl $(XMLDIR)/aliyah.xml $(XMLDIR)/festival.xml
	mkdir -p $(SEDROT)
	./calc_triennial.pl -f $(CSVDIR)/fullkriyah.csv \
		-t $(CSVDIR)/triennial.csv \
		 $(CSVDIR)/aliyah.xml $(CSVDIR)/festival.xml $(SEDROT)
	rm -f $(CSVDIR)/fullkriyah.csv.gz $(CSVDIR)/triennial.csv.gz
	gzip -9 $(CSVDIR)/fullkriyah.csv $(CSVDIR)/triennial.csv

$(HOLIDAYS)/purim.html: gen_festival.pl $(XMLDIR)/festival.xml
	mkdir -p $(HOLIDAYS)
	./gen_festival.pl $(XMLDIR)/festival.xml $(HOLIDAYS)

$(DBDIR)/zips99.db: zips2db.pl zip99/zipnov99.csv zip99/c_01au03.csv
	rm -f zip99new.db
	./zips2db.pl zip99new.db zip99/zipnov99.csv zip99/c_01au03.csv
	mv zip99new.db $@
