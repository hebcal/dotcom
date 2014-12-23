window['hebcal'] = window['hebcal'] || {};

window['hebcal'].isDateInRange = function(begin, end, now) {
    var t = now ? moment(now) : moment();
    return (t.isSame(begin) || t.isAfter(begin)) && (t.isSame(end) || t.isBefore(end));
};

window['hebcal'].transformHebcalEvents = function(events, lang) {
    var evts = events.map(function(src) {
        var allDay = src.date.indexOf('T') == -1,
            title = allDay ? src.title : src.title.substring(0, src.title.indexOf(':')),
            dest = {
                title: title,
                start: src.date,
                className: src.category,
                allDay: allDay
            };
        if (src.yomtov) {
            dest.className += " yomtov";
        }
        if (src.memo) {
            dest.description = src.memo;
        }
        if (src.link) {
            dest.url = src.link;
        }
        if (src.hebrew) {
            dest.hebrew = src.hebrew;
            if (lang === 'h') {
                dest.title = src.hebrew;
                dest.className += " hebrew";
            }
        }
        return dest;
    });
    if (lang === 'ah' || lang === 'sh') {
        var dest = [];
        evts.forEach(function(evt) {
            dest.push(evt);
            if (evt.hebrew) {
                var tmp = $.extend({}, evt, {
                    title: evt.hebrew,
                    className: evt.className + " hebrew"
                });
                dest.push(tmp);
            }
        });
        evts = dest;
    }
    return evts;
};

window['hebcal'].renderCalendar = function(lang, singleMonth) {
    var evts = window['hebcal'].transformHebcalEvents(window['hebcal'].events, lang),
        today = moment(),
        todayInRange = window['hebcal'].isDateInRange(evts[0].start, evts[evts.length - 1].start, today),
        defaultDate = todayInRange ? today : evts[0].start,
        rightNav = singleMonth ? '' : (lang === 'h' ? 'next prev' : 'prev next');
    $('#full-calendar').fullCalendar({
        header: {
            left: 'title',
            center: '',
            right: rightNav
        },
        isRTL: lang === 'h',
        fixedWeekCount: false,
        contentHeight: 580,
        defaultDate: defaultDate,
        events: evts
    });
    if (!singleMonth) {
        $("body").keydown(function(e) {
            if (e.keyCode == 37) {
                $('#full-calendar').fullCalendar('prev');
            } else if (e.keyCode == 39) {
                $('#full-calendar').fullCalendar('next');
            }
        });
    }
};

window['hebcal'].splitByMonth = function(events) {
    var out = [],
        prevMonth = '',
        monthEvents;
    events.forEach(function(evt) {
        var m = moment(evt.date),
            month = m.format("YYYY-MM");
        if (month !== prevMonth) {
            prevMonth = month;
            monthEvents = [];
            out.push({
                month: month,
                events: monthEvents
            });
        }
        monthEvents.push(evt);
    });
    return out;
};

window['hebcal'].tableRow = function(evt) {
    var m = moment(evt.date),
        dow = m.format('ddd'),
        dateStr = m.format('DD-MMM-YYYY'),
        subj = evt.title,
        className = evt.category;
    if (evt.yomtov) {
        className += " yomtov";
    }
    if (evt.link) {
        var atitle = evt.memo ? ' title="' + evt.memo + '"' : '';
        subj = '<a' + atitle + ' href="' + evt.link + '">' + subj + '</a>';
    }
    return '<tr><td>' + dow + '</td><td>' + dateStr + '</td><td><span class="table-event ' + className + '">' + subj + '</span></td></tr>';
};

window['hebcal'].monthHtml = function(month) {
    var date = month.month + "-01",
        m = moment(date),
        calId = 'cal-' + month.month,
        divBegin = '<div id="' + calId + '">',
        divEnd = '</div><!-- #' + calId + ' -->',
        heading = '<h3>' + m.format('MMMM YYYY') + '</h3>',
        tableHead = '<table class="table table-striped"><col style="width:20px"><col style="width:110px"><col><tbody>',
        tableFoot = '</tbody></table>',
        tableContents = month.events.map(window['hebcal'].tableRow);
    return divBegin + heading + tableHead + tableContents.join('') + tableFoot + divEnd;
};

window['hebcal'].renderMonthTables = function() {
    var months = window['hebcal'].splitByMonth(window['hebcal'].events),
        monthHtmls = months.map(window['hebcal'].monthHtml);

    $('#full-calendar').fullCalendar('destroy');
    $('body').off('keydown');
    $('#hebcal-results').html(monthHtmls.join(''));
}