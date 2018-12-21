/*
 * hebcal calendar HTML client-side rendering
 *
 * requries jQuery, Moment.js, and FullCalendar.io
 *
 * Copyright (c) 2017  Michael J. Radwin.
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
        evt.link.substring(0, 22) !== 'https://www.hebcal.com') {
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
            if (e.keyCode === 37) {
                $('#full-calendar').fullCalendar('prev');
            } else if (e.keyCode === 39) {
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
        dateStr = m.format('ddd DD MMM'),
        allDay = evt.date.indexOf('T') == -1,
        lang = window['hebcal'].lang || 's',
        subj = evt.title,
        timeStr = '',
        timeTd,
        className = window['hebcal'].getEventClassName(evt);
    if (evt.category === 'dafyomi') {
        subj = subj.substring(subj.indexOf(':') + 1);
    } else if (evt.category === 'candles' || evt.category === 'havdalah') {
        // "Candle lighting: foo" or "Havdalah (42 min): foo"
        subj = evt.title.substring(0, evt.title.indexOf(':'));
    }
    if (!allDay) {
        var timeMatch = evt.title.match(/\d+:\d+\w*$/);
        if (timeMatch && timeMatch.length) {
            timeStr = timeMatch[0];
        }
        if (subj.startsWith('Chanukah: ') ||
            (typeof evt.title_orig === 'string' && evt.title_orig.startsWith('Chanukah: '))) {
            var colon = subj.lastIndexOf(':'),
                colon2 = subj.lastIndexOf(':', colon - 1);
            if (colon2 > 0) {
                subj = subj.substring(0, colon2);
            }
        }
    }
    timeTd = window['hebcal'].cconfig['geo'] === 'none' ? '' : '<td>' + timeStr + '</td>';
    if (evt.hebrew) {
        var hebrewHtml = '<span lang="he" dir="rtl">' + evt.hebrew + '</span>';
        if (lang == 'h') {
            subj = hebrewHtml;
        } else if (lang.indexOf('h') != -1) {
            subj += " / " + hebrewHtml;
        }
    }
    if (evt.link) {
        var atitle = evt.memo ? ' title="' + evt.memo + '"' : '';
        subj = '<a' + atitle + ' href="' + evt.link + '">' + subj + '</a>';
    }
    return '<tr><td>' + dateStr + '</td>' + timeTd + '<td><span class="table-event ' + className + '">' + subj + '</span></td></tr>';
};

window['hebcal'].monthHtml = function(month) {
    var date = month.month + "-01",
        m = moment(date, moment.ISO_8601),
        divBegin = '<div class="month-table">',
        divEnd = '</div><!-- .month-table -->',
        heading = '<h3>' + m.format('MMMM YYYY') + '</h3>',
        timeColumn = window['hebcal'].cconfig['geo'] === 'none' ? '' : '<col style="width:27px">',
        tableHead = '<table class="table table-striped"><col style="width:116px">' + timeColumn + '<col><tbody>',
        tableFoot = '</tbody></table>',
        tableContents = month.events.map(window['hebcal'].tableRow);
    return divBegin + heading + tableHead + tableContents.join('') + tableFoot + divEnd;
};

window['hebcal'].renderMonthTables = function() {
    if (typeof window['hebcal'].monthTablesRendered === 'undefined') {
        var months = window['hebcal'].splitByMonth(window['hebcal'].events);
        months.forEach(function(month) {
            var html = window['hebcal'].monthHtml(month),
                selector = '#cal-' + month.month + ' .agenda';
            $(selector).html(html);
        });
        window['hebcal'].monthTablesRendered = true;
    }
}

window['hebcal'].createCityTypeahead = function(autoSubmit) {
    var hebcalCities = new Bloodhound({
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
        queryTokenizer: Bloodhound.tokenizers.whitespace,
        remote: '/complete.php?q=%QUERY',
        limit: 8
    });

    hebcalCities.initialize();

    $('#city-typeahead').typeahead(null, {
        name: 'hebcal-city',
        displayKey: 'value',
        source: hebcalCities.ttAdapter(),
        templates: {
            empty: function(ctx) {
                var encodedStr = ctx.query.replace(/[\u00A0-\u9999<>\&]/gim, function(i) {
                    return '&#' + i.charCodeAt(0) + ';';
                });
                return '<div class="tt-suggestion">Sorry, no city names match <b>' + encodedStr + '</b>.</div>';
            },
            suggestion: function(ctx) {
                if (typeof ctx.geo === "string" && ctx.geo == "zip") {
                    return '<p>' + ctx.asciiname + ', ' + ctx.admin1 + ' <strong>' + ctx.id + '</strong> - United States</p>';
                } else {
                    var ctry = ctx.country && ctx.country == "United Kingdom" ? "UK" : ctx.country,
                        ctryStr = ctry || '',
                        s = '<p><strong>' + ctx.asciiname + '</strong>';
                    if (ctry && typeof ctx.admin1 === "string" && ctx.admin1.length > 0 && ctx.admin1.indexOf(ctx.asciiname) != 0) {
                        ctryStr = ctx.admin1 + ', ' + ctryStr;
                    }
                    if (ctryStr) {
                        ctryStr = ' - <small>' + ctryStr + '</small>';
                    }
                    return s + ctryStr + '</p>';
                }
            }
        }
    }).on('typeahead:selected', function(obj, datum, name) {
        if (typeof datum.geo === "string" && datum.geo == "zip") {
            $('#geo').val('zip');
            $('#zip').val(datum.id);
            if (autoSubmit) {
                $('#geonameid').remove();
            } else {
                $('#c').val('on');
                $('#geonameid').val('');
                $('#city').val('');
            }
        } else {
            $('#geo').val('geoname');
            $('#geonameid').val(datum.id);
            if (autoSubmit) {
                $('#zip').remove();
            } else {
                $('#c').val('on');
                $('#zip').val('');
                $('#city').val('');
            }
        }
        if (autoSubmit) {
            $('#shabbat-form').submit();
        }
    }).bind("keyup keypress", function(e) {
        if (!autoSubmit && !$(this).val()) {
            $('#geo').val('none');
            $('#c').val('off');
            $('#geonameid').val('');
            $('#zip').val('');
            $('#city').val('');
        }
        var code = e.keyCode || e.which;
        if (code == 13) {
            var val0 = $('#city-typeahead').typeahead('val'),
                val = (typeof val0 === 'string') ? val0.trim() : '',
                numericRe = /^\d+$/;
            if (val.length == 5 && numericRe.test(val)) {
                $('#geo').val('zip');
                $('#zip').val(val);
                if (autoSubmit) {
                    $('#geonameid').remove();
                } else {
                    $('#c').val('on');
                    $('#geonameid').val('');
                    $('#city').val('');
                }
                return true; // allow form to submit
            }
            e.preventDefault();
            return false;
        }
    });
}