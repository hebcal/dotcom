all: ../help/holidays.html ../sedrot/bereshit.html ../hebcal/sedrot.db

../hebcal/sedrot.db: sedrot_db.pl ../dist/aliyah.xml
	./sedrot_db.pl ../dist/aliyah.xml ../hebcal/sedrot.db

../hebcal/holidays.db ../help/holidays.html: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini ../help/holidays.html ../hebcal/holidays.db

../sedrot/bereshit.html: calc_triennial.pl ../dist/aliyah.xml
	./calc_triennial.pl -f ../dist/fullkriyah.csv ../dist/aliyah.xml ../sedrot/

