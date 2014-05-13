var fs = require('fs'),
    twitter = require('ntwitter'),
    ini = require('ini'),
    Hebcal = require('hebcal');

var iniPath = '/home/hebcal/local/bin/hebcal-dot-com.ini',
    config = ini.parse(fs.readFileSync(iniPath, 'utf-8'));

function upcomingDow(searchingDow) {
    var today = new Date(),
        todayDow = today.getDay();
    if (searchingDow == todayDow) {
        return today;
    }
    var upcoming = new Date(today);
    upcoming.setHours(0, 0, 0, 0);
    upcoming.setDate(upcoming.getDate() + (searchingDow - todayDow));
    if (searchingDow < todayDow) {
        upcoming.setDate(upcoming.getDate() + 7);
    }
    return upcoming;
}

var saturday = upcomingDow(6);
console.log(saturday);
var parashah = new Hebcal.HDate(saturday).getSedra().join('-');

var twitterStatus = 'This week\'s #Torah portion is Parashat ' + parashah;
console.log(twitterStatus);

var twit = new twitter({
  consumer_key: config['hebcal.twitter.consumer_key'],
  consumer_secret: config['hebcal.twitter.consumer_secret'],
  access_token_key: config['hebcal.twitter.token'],
  access_token_secret: config['hebcal.twitter.token_secret']
});

twit.updateStatus(twitterStatus,
    function (err, data) {
        console.log(data);
        process.exit();
    }
);
