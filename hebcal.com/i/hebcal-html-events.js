window['hebcal'] = window['hebcal'] || {};
window['hebcal'].getEventTableStr = function(events) {
    var months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' ');
    var dow = 'Sun Mon Tue Wed Thu Fri Sat'.split(' ');
    var s = '<table class="table table-striped"><col style="width:20px"><col style="width:110px"><col><tbody>';
    events.forEach(function(evt) {
        var dt = new Date(evt.date),
            mday = dt.getUTCDate(),
            subject = evt.title;
        if (mday < 10) {
            mday = "0" + String(mday);
        }
        if (evt.link) {
            subject = '<a href="' + evt.link + '">' + subject + '</a>';
        }
        s += "<tr><td>" + dow[dt.getUTCDay()] + "</td>";
        s += "<td>" + mday + "-" + months[dt.getUTCMonth()] + "-" + dt.getUTCFullYear() + "</td>";
        s += "<td>" + subject + "</td>";
        s += "</tr>\n";
    });
    s += "</tbody></table>\n";
    return s;
}