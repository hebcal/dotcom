all: ../help/holidays.html ../sedrot/bereshit.html ../hebcal/sedrot.db

holidays: ../holidays/purim.html

../hebcal/sedrot.db: sedrot_db.pl ../dist/aliyah.xml
	./sedrot_db.pl ../dist/aliyah.xml ../hebcal/sedrot.db

../hebcal/holidays.db ../help/holidays.html: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini ../help/holidays.html ../hebcal/holidays.db

../sedrot/bereshit.html: calc_triennial.pl ../dist/aliyah.xml ../dist/festival.xml
	mkdir -p ../sedrot
	./calc_triennial.pl -f ../dist/fullkriyah.csv -t../dist/triennial.csv \
		 ../dist/aliyah.xml ../dist/festival.xml ../sedrot/
	rm -f ../dist/fullkriyah.csv.gz ../dist/triennial.csv.gz
	gzip -9 ../dist/fullkriyah.csv ../dist/triennial.csv

../holidays/purim.html: gen_festival.pl ../dist/festival.xml
	mkdir -p ../holidays
	./gen_festival.pl ../dist/festival.xml ../holidays/
