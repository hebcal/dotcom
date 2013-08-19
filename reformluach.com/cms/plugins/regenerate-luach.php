<?php
# get correct id for plugin
$thisfile=basename(__FILE__, ".php");

$plugin_id = $thisfile;
$tab_name = $plugin_id; // can be unique if you so choose

# register plugin
register_plugin(
    $plugin_id,             //Plugin id
    'Regenerate Luach',         //Plugin name
    '0.8',            //Plugin version
    'Michael Radwin',              //Plugin author
    'http://www.radwin.org/michael/',                    //author website
    'Click this tab to regenerate the Luach',                //Plugin description
    $tab_name,        //page type - on which admin tab to display
    'tabcalloutfunc'  //main function (administration)
);

add_action('nav-tab','createNavTab',array($tab_name,$plugin_id,'Regenerate Luach','tabargument'));

function tabcalloutfunc(){
  echo "<pre>\n";
  flush();
  system("date");
  flush();
  system("make --directory=/home/hebcal/web/hebcal.com/bin reform-luach");
  flush();
  system("date");
  flush();
  echo "</pre>\n";
  flush();
}

?>
