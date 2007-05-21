DISTDIR = $(CURDIR)/../dist
XMLDIR = $(DISTDIR)
XML_ALIYAH = $(XMLDIR)/aliyah.xml
XML_FESTIVAL = $(XMLDIR)/festival.xml
SITE_PERL = /home/hebcal/local/share/perl/site_perl
CSVDIR = $(DISTDIR)
SEDROT = ../sedrot
DBDIR = ../hebcal
HOLIDAYS = ../holidays

all: xml2perl sedrot holidays

holidays: $(HOLIDAYS)/purim.html

sedrot: $(SEDROT)/bereshit.html

xml2perl: $(SITE_PERL)/HebcalConst.pm

$(SITE_PERL)/HebcalConst.pm: $(XML_ALIYAH) $(XML_FESTIVAL) gen_const.pl
	./gen_const.pl $(SITE_PERL)/HebcalConst.pm

$(SEDROT)/bereshit.html: calc_triennial.pl $(XML_ALIYAH) $(XML_FESTIVAL)
	mkdir -p $(SEDROT)
	./calc_triennial.pl -f $(CSVDIR)/fullkriyah.csv \
		-t $(CSVDIR)/triennial.csv \
		 $(CSVDIR)/aliyah.xml $(CSVDIR)/festival.xml $(SEDROT)

$(HOLIDAYS)/purim.html: gen_festival.pl $(XML_FESTIVAL)
	mkdir -p $(HOLIDAYS)
	./gen_festival.pl $(XML_FESTIVAL) $(HOLIDAYS)

$(DBDIR)/zips99.db: zips2db.pl zip99/zipnov99.csv zip99/c_10fe06.csv
	rm -f zip99new.db
	./zips2db.pl zip99new.db zip99/zipnov99.csv zip99/c_10fe06.csv
	mv zip99new.db $@

RELEASEFILES = 	web/hebcal.com/dist/ChangeLog.txt \
		web/hebcal.com/dist/*.xml \
		web/hebcal.com/hebcal/*.cgi \
		web/hebcal.com/shabbat/*.cgi \
		web/hebcal.com/yahrzeit/*.cgi \
		web/hebcal.com/bin/Makefile \
		web/hebcal.com/bin/*.pl \
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
