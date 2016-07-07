DISTDIR = $(CURDIR)/../dist
XMLDIR = $(DISTDIR)
XML_ALIYAH = $(XMLDIR)/aliyah.xml
XML_FESTIVAL = $(XMLDIR)/festival.xml
CITIES_TXT = $(XMLDIR)/cities2.txt
CITIES_JSON = ../etc/cities.js
SITE_PERL = /home/hebcal/local/share/perl/site_perl
SEDROT = ../sedrot
DBDIR = ../hebcal
HOLIDAYS = ../holidays
CONVERTER_SEDRA = ../converter/sedra/20/2099.inc
REFORM_LUACH_DB = $(DBDIR)/reform-luach.sqlite3
REFORM_LUACH_TMPDIR = /tmp/hebcal-reform-luach
REFORM_LUACH_OUTDIR = ../../reformluach.com
REFORM_LUACH_XML_DATADIR = ../../reformluach.com/cms/data
XML_REFORM_LUACH = $(REFORM_LUACH_XML_DATADIR)/other/pages.xml
PODIR = ../../hebcal/po
POFILES = $(PODIR)/*.po

all: xml2perl sedrot holidays converter

holidays: $(HOLIDAYS)/purim

sedrot: $(SEDROT)/bereshit

xml2perl: $(SITE_PERL)/HebcalConst.pm

converter: $(CONVERTER_SEDRA)

reform-luach: $(REFORM_LUACH_OUTDIR)/index.html

$(SITE_PERL)/HebcalConst.pm $(CITIES_JSON): $(XML_ALIYAH) $(XML_FESTIVAL) $(CITIES_TXT) gen_const.pl hebcal $(POFILES)
	./gen_const.pl $(SITE_PERL)/HebcalConst.pm ../pear/Hebcal/const.inc $(CITIES_JSON)

$(CONVERTER_SEDRA): gen_daily_sedra.pl hebcal
	./gen_daily_sedra.pl 1900 2099

$(SEDROT)/bereshit: calc_triennial.pl $(XML_ALIYAH) $(XML_FESTIVAL)
	mkdir -p $(SEDROT)
	./calc_triennial.pl \
		--fullkriyah \
		--triennial \
		--dbfile $(DBDIR)/luach.sqlite3 \
		$(DISTDIR)/aliyah.xml $(DISTDIR)/festival.xml $(SEDROT)
	./calc_triennial.pl \
		--israel \
		--nohtml \
		--fullkriyah \
		--dbfile $(DBDIR)/luach.sqlite3 \
		$(DISTDIR)/aliyah.xml $(DISTDIR)/festival.xml $(SEDROT)

$(HOLIDAYS)/purim: gen_festival.pl $(XML_FESTIVAL)
	mkdir -p $(HOLIDAYS)
	./gen_festival.pl -v \
		$(XML_FESTIVAL) $(HOLIDAYS)

$(REFORM_LUACH_OUTDIR)/index.html: gen_luach.pl $(REFORM_LUACH_DB) $(XML_REFORM_LUACH)
	./gen_luach.pl -v \
		$(XML_FESTIVAL) \
		$(REFORM_LUACH_DB) \
		$(REFORM_LUACH_XML_DATADIR) \
		$(REFORM_LUACH_OUTDIR)

$(REFORM_LUACH_DB): calc_triennial.pl $(XML_ALIYAH) $(XML_FESTIVAL)
	mkdir -p $(REFORM_LUACH_TMPDIR)
	./calc_triennial.pl \
		-i \
		-f \
		-d $(REFORM_LUACH_DB) \
		 $(DISTDIR)/aliyah.xml $(DISTDIR)/festival.xml $(REFORM_LUACH_TMPDIR)
	rm -rf $(REFORM_LUACH_TMPDIR)

converter: ../converter/sedra/19/1900.inc

../converter/sedra/19/1900.inc: gen_daily_sedra.pl hebcal
	./gen_daily_sedra.pl 1900 2099

clean:
		rm -f $(SEDROT)/*
		rm -f $(HOLIDAYS)/*
		rm -f ../shabbat/browse/*
