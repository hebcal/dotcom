DISTDIR = $(CURDIR)/../dist
XMLDIR = $(DISTDIR)
XML_ALIYAH = $(XMLDIR)/aliyah.xml
XML_FESTIVAL = $(XMLDIR)/festival.xml
CITIES_TXT = $(XMLDIR)/cities.txt
CITIES_JSON = ../etc/cities.js
SITE_PERL = /home/hebcal/local/share/perl/site_perl
CSVDIR = $(DISTDIR)
SEDROT = ../sedrot
DBDIR = ../hebcal
HOLIDAYS = ../holidays

all: xml2perl sedrot holidays json

holidays: $(HOLIDAYS)/purim.html

sedrot: $(SEDROT)/bereshit.html

xml2perl: $(SITE_PERL)/HebcalConst.pm

$(SITE_PERL)/HebcalConst.pm: $(XML_ALIYAH) $(XML_FESTIVAL) $(CITIES_TXT) gen_const.pl hebcal
	./gen_const.pl $(SITE_PERL)/HebcalConst.pm

json: $(CITIES_JSON)

$(CITIES_JSON): $(CITIES_TXT) gen_cities_json.pl
	./gen_cities_json.pl $(CITIES_TXT) opencountrycodes.xml $(CITIES_JSON)

$(SEDROT)/bereshit.html: calc_triennial.pl $(XML_ALIYAH) $(XML_FESTIVAL)
	mkdir -p $(SEDROT)
	./calc_triennial.pl -f $(CSVDIR)/fullkriyah.csv \
		-t $(CSVDIR)/triennial.csv \
		 $(CSVDIR)/aliyah.xml $(CSVDIR)/festival.xml $(SEDROT)

$(HOLIDAYS)/purim.html: gen_festival.pl $(XML_FESTIVAL)
	mkdir -p $(HOLIDAYS)
	./gen_festival.pl -v $(XML_FESTIVAL) $(HOLIDAYS)

converter: ../converter/sedra/19/1900.inc

../converter/sedra/19/1900.inc: gen_daily_sedra.pl hebcal
	./gen_daily_sedra.pl 1900 2099

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
