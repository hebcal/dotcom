all: ../help/holidays.html ../sedrot/index.html

../help/holidays.html: gen_holidays.pl holidays.ini
	./gen_holidays.pl holidays.ini ../help/holidays.html

../sedrot/index.html: gen_sedrot.pl sedrot.ini
	./gen_sedrot.pl sedrot.ini ../sedrot/
