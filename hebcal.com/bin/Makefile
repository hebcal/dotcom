all: ../help/holidays.html ../sedrot/bereshit.html

../help/holidays.html: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini ../help/holidays.html

../sedrot/bereshit.html: calc_triennial.pl ../dist/aliyah.xml
	./calc_triennial.pl -f ../dist/fullkriyah.csv ../dist/aliyah.xml ../sedrot/
