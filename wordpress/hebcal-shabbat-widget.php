<?php
/**
 * Plugin Name: Hebcal Shabbat Times
 * Plugin URI: http://www.hebcal.com/home/shabbat/widgets
 * Description: Use this widget to display Shabbat candle lighting times for a USA zip code
 * Version: 1.6
 * Author: Michael J. Radwin
 * Author URI: http://www.radwin.org/michael/
 * License: MIT
 * License URI: https://opensource.org/licenses/MIT
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

class Hebcal_Shabbat_Widget extends WP_Widget {
    /**
     * Widget setup.
     */
    function Hebcal_Shabbat_Widget() {
        /* Widget settings. */
        $widget_ops = array('classname' => 'hebcal-shabbat',
                    'description' => 'displays Shabbat candle lighting times for a USA zip code or world city');

        /* Widget control settings. */
        $control_ops = array('width' => 200,
                     'height' => 200,
                     'id_base' => 'hebcal-shabbat-widget');

        /* Create the widget. */
        $this->WP_Widget('hebcal-shabbat-widget', 'Hebcal Shabbat Times', $widget_ops, $control_ops);
    }

    /**
     * How to display the widget on the screen.
     */
    function widget($args, $instance) {
        extract($args);

        /* Our variables from the widget settings. */
        $title = apply_filters('widget_title', $instance['title']);
        $ashkenazis_checked = isset($instance['a']) ? $instance['a'] : false;
        $ashkenazis = $ashkenazis_checked ? 'on' : 'off';

        $out = <<<EOD
<div class="hebcal-container">
<div class="hebcal-$instance[zip]"></div><!-- .hebcal-$instance[zip] -->
<div class="copyright">
<small>Powered by <a href="//www.hebcal.com/shabbat/?geo=zip&amp;zip=$instance[zip]&amp;m=$instance[m]&amp;a=$ashkenazis&amp;utm_source=shabbat1c&amp;utm_medium=wp">Hebcal Shabbat Times</a></small>
</div><!-- .copyright -->
</div><!-- .hebcal-container -->
<script type="text/javascript">
var formatShortDate = function(str) {
    var monthNames = [
      "January", "February", "March",
      "April", "May", "June", "July",
      "August", "September", "October",
      "November", "December"
    ];
    var yearStr = str.substr(0,4);
    var monthStr = str.substr(5,2);
    var dayStr = str.substr(8,2);
    var month = (+monthStr) - 1;
    return dayStr + ' ' + monthNames[month] + ' ' + yearStr;
};
var formatHebcalShabbatEvents = function(response) {
    if (typeof response === 'object' && response.items && response.items.length) {
        var arr = response.items.map(function(x) {
            if (typeof x === 'object' && typeof x.category === 'string') {
                if (x.category === 'candles') {
                    return x.title;
                } else if (x.category === 'parashat') {
                    return 'Torah portion: <a href="' + x.link + '?utm_source=shabbat1c&amp;utm_medium=wp">' + x.title + '</a>';
                } else if (x.category === 'havdalah') {
                    return x.title.replace(/\s+\(\d+ min\)/, '');
                } else {
                    var dateStr = formatShortDate(x.date),
                        str = x.title;
                    if (typeof x.link === 'string') {
                        str = '<a href="' + x.link + '?utm_source=shabbat1c&amp;utm_medium=wp">' + x.title + '</a>';
                    }
                    return str + ' on ' + dateStr;
                }
            }
        });
        arr = arr.filter(function(n){ return n != undefined });
        return arr;
    }
    return [];
};

jQuery.ajax({
  url: "//www.hebcal.com/shabbat/?cfg=json;geo=zip;zip=$instance[zip];m=$instance[m];a=$ashkenazis",
  cache: true
}).done(function(data) {
    var h3 = typeof data.title === 'string' ? '<p class="lead">' + data.title + '</p>' : '';
    var hebcalEvents = formatHebcalShabbatEvents(data);
    var html = hebcalEvents.map(function(x) { return '<li>' + x + '</li>\\n'; }).join('');
    jQuery('.hebcal-$instance[zip]').html(h3 + '<ul class="hebcal-results">' + html + '</ul>');
});
</script>
EOD;

        echo $before_widget;
        echo $before_title, $title, $after_title;
        echo $out;
        echo $after_widget;
    }

    /**
     * Update the widget settings.
     */
    function update($new_instance, $old_instance) {
        $instance = $old_instance;

        /* Strip tags for title and name to remove HTML (important for text inputs). */
        $instance['title'] = strip_tags($new_instance['title']);
        $instance['zip'] = strip_tags($new_instance['zip']);
        $instance['m'] = $new_instance['m'];
        $instance['a'] = $new_instance['a'];

        return $instance;
    }

    /**
     * Displays the widget settings controls on the widget panel.
     * Make use of the get_field_id() and get_field_name() function
     * when creating your form elements. This handles the confusing stuff.
     */
    function form($instance) {
      /* Set up some default widget settings. */
      $defaults = array('zip' => '90210', 'm' => '72');
      $instance = wp_parse_args((array) $instance, $defaults); ?>

        <!-- Title: Text Input -->
           <p>
           <label for="<?php echo $this->get_field_id('title'); ?>">Title:</label>
          <input id="<?php echo $this->get_field_id('title'); ?>" name="<?php echo $this->get_field_name('title'); ?>" value="<?php echo $instance['title']; ?>" />
        </p>

        <!-- Zip code: Text Input -->
           <p>
           <label for="<?php echo $this->get_field_id('zip'); ?>">Zip code:</label>
          <input id="<?php echo $this->get_field_id('zip'); ?>" name="<?php echo $this->get_field_name('zip'); ?>" value="<?php echo $instance['zip']; ?>" size="5" maxlength="5" />
        </p>

    <!-- Havdalah minutes past sundown : Text Input -->
        <p>
        <label for="<?php echo $this->get_field_id('m'); ?>">Havdalah minutes past sundown:</label>
        <input id="<?php echo $this->get_field_id('m'); ?>" name="<?php echo $this->get_field_name('m'); ?>" value="<?php echo $instance['m']; ?>" size="2" maxlength="2" />
        </p>

        <!-- Use Ashkenazis Hebrew transliterations? Checkbox -->
        <p>
            <input class="checkbox" type="checkbox" <?php if ($instance['a' ]) echo ' checked="checked"' ?> id="<?php echo $this->get_field_id('a'); ?>" name="<?php echo $this->get_field_name('a'); ?>" />
            <label for="<?php echo $this->get_field_id('a'); ?>">Use Ashkenazis Hebrew transliterations</label>
        </p>
    <?php
    }
}

add_action('widgets_init', 'hebcal_load_widgets');

function hebcal_load_widgets() {
    register_widget('Hebcal_Shabbat_Widget');
}

?>
