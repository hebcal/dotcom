DISTDIR = $(CURDIR)/../dist
XMLDIR = $(DISTDIR)
CSVDIR = $(DISTDIR)
SEDROT = ../sedrot
DBDIR = ../hebcal
HOLIDAYS = ../holidays

all: sedrot holidays

holidays: $(HOLIDAYS)/purim.html

sedrot: $(SEDROT)/bereshit.html

$(SEDROT)/bereshit.html: calc_triennial.pl $(XMLDIR)/aliyah.xml $(XMLDIR)/festival.xml
	mkdir -p $(SEDROT)
	./calc_triennial.pl -f $(CSVDIR)/fullkriyah.csv \
		-t $(CSVDIR)/triennial.csv \
		 $(CSVDIR)/aliyah.xml $(CSVDIR)/festival.xml $(SEDROT)

$(HOLIDAYS)/purim.html: gen_festival.pl $(XMLDIR)/festival.xml
	mkdir -p $(HOLIDAYS)
	./gen_festival.pl $(XMLDIR)/festival.xml $(HOLIDAYS)

$(DBDIR)/zips99.db: zips2db.pl zip99/zipnov99.csv zip99/c_01au03.csv
	rm -f zip99new.db
	./zips2db.pl zip99new.db zip99/zipnov99.csv zip99/c_01au03.csv
	mv zip99new.db $@

RELEASEFILES = 	web/hebcal.com/dist/ChangeLog.txt \
		web/hebcal.com/dist/*.xml \
		web/hebcal.com/hebcal/*.cgi \
		web/hebcal.com/shabbat/*.cgi \
		web/hebcal.com/yahrzeit/*.cgi \
		web/hebcal.com/bin/Makefile \
		web/hebcal.com/bin/*.pl \
		web/hebcal.com/bin/*.ini \
		local/share/perl/site_perl/Hebcal.pm \
		local/share/perl/site_perl/Palm/DBA.pm \
		web/hebcal.com/pear/Hebcal/*.inc \
		web/hebcal.com/shabbat/*.php \
		web/hebcal.com/wap-shabbat.php \
		web/hebcal.com/converter/index.php \
		web/hebcal.com/link/index.php \
		web/hebcal.com/email/index.php \
		$(NULL)

release: $(DISTDIR)/hebcal-dot-com.tar.gz

$(DISTDIR)/hebcal-dot-com.tar.gz: $(patsubst %,../../../%,$(RELEASEFILES))
	cd ../../.. && tar -cvf $(DISTDIR)/hebcal-dot-com.tar $(RELEASEFILES)
	rm -f $(DISTDIR)/hebcal-dot-com.tar.gz
	gzip -9 $(DISTDIR)/hebcal-dot-com.tar
