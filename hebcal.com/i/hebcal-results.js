/*
 * hebcal calendar HTML client-side rendering
 *
 * requries jQuery, Moment.js, and FullCalendar.io
 *
 * Copyright (c) 2014  Michael J. Radwin.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 *  - Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 *
 *  - Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

window['hebcal'] = window['hebcal'] || {};

window['hebcal'].isDateInRange = function(begin, end, now) {
    var t = now ? moment(now) : moment();
    return (t.isSame(begin) || t.isAfter(begin)) && (t.isSame(end) || t.isBefore(end));
};

window['hebcal'].getEventClassName = function(evt) {
    var className = evt.category;
    if (evt.yomtov) {
        className += ' yomtov';
    }
    if (typeof evt.link === 'string' &&
        evt.link.substring(0, 4) === 'http' &&
        evt.link.substring(0, 21) !== 'http://www.hebcal.com') {
        className += ' outbound';
    }
    return className;
};

window['hebcal'].transformHebcalEvents = function(events, lang) {
    var evts = events.map(function(src) {
        var allDay = src.date.indexOf('T') == -1,
            title = allDay ? src.title : src.title.substring(0, src.title.indexOf(':')),
            dest = {
                title: title,
                start: moment(src.date, moment.ISO_8601),
                className: window['hebcal'].getEventClassName(src),
                allDay: allDay
            };
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
    var evts = window['hebcal'].fullCalendarEvents || window['hebcal'].transformHebcalEvents(window['hebcal'].events, lang),
        today = moment(),
        todayInRange = window['hebcal'].isDateInRange(evts[0].start, evts[evts.length - 1].start, today),
        defaultDate = todayInRange ? today : evts[0].start,
        rightNav = singleMonth ? '' : (lang === 'h' ? 'next prev' : 'prev next');
    window['hebcal'].fullCalendarEvents = evts;
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
        timezone: false,
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
        var m = moment(evt.date, moment.ISO_8601),
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
    var m = moment(evt.date, moment.ISO_8601),
        dow = m.format('ddd'),
        dateStr = m.format('DD-MMM-YYYY'),
        subj = evt.title,
        className = window['hebcal'].getEventClassName(evt);
    if (evt.link) {
        var atitle = evt.memo ? ' title="' + evt.memo + '"' : '';
        subj = '<a' + atitle + ' href="' + evt.link + '">' + subj + '</a>';
    }
    return '<tr><td>' + dow + '</td><td>' + dateStr + '</td><td><span class="table-event ' + className + '">' + subj + '</span></td></tr>';
};

window['hebcal'].monthHtml = function(month) {
    var date = month.month + "-01",
        m = moment(date, moment.ISO_8601),
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
    var months = window['hebcal'].eventsByMonth || window['hebcal'].splitByMonth(window['hebcal'].events),
        monthHtmls = months.map(window['hebcal'].monthHtml);

    window['hebcal'].eventsByMonth = months;

    $('#full-calendar').fullCalendar('destroy');
    $('body').off('keydown');
    $('#hebcal-results').html(monthHtmls.join(''));
}