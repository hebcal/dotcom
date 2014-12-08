window['hebcal'] = window['hebcal'] || {};
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
            e.preventDefault();
            return false;
        }
    });
}