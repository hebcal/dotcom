all: ../hebcal/holidays.db ../sedrot/bereshit.html ../hebcal/sedrot.db

holidays: ../holidays/purim.html

../hebcal/sedrot.db: sedrot_db.pl ../dist/aliyah.xml
	./sedrot_db.pl ../dist/aliyah.xml $@

../hebcal/holidays.db: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini /dev/null $@

../sedrot/bereshit.html: calc_triennial.pl ../dist/aliyah.xml ../dist/festival.xml
	mkdir -p ../sedrot
	./calc_triennial.pl -f ../dist/fullkriyah.csv -t../dist/triennial.csv \
		 ../dist/aliyah.xml ../dist/festival.xml ../sedrot/
	rm -f ../dist/fullkriyah.csv.gz ../dist/triennial.csv.gz
	gzip -9 ../dist/fullkriyah.csv ../dist/triennial.csv

../holidays/purim.html: gen_festival.pl ../dist/festival.xml
	mkdir -p ../holidays
	./gen_festival.pl ../dist/festival.xml ../holidays/

../hebcal/zips99.db: zips2db.pl zip99/zipnov99.csv zip99/c_01au03.csv
	rm -f zip99new.db
	./zips2db.pl zip99new.db zip99/zipnov99.csv zip99/c_01au03.csv
	mv zip99new.db $@
