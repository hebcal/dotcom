<?php
// $Id$
// $URL$
header("Content-Type: text/vnd.wap.wml");
echo '<?xml version="1.0"?>', "\n";

if ($_SERVER['HTTP_X_UP_SUBNO'])
{
    $id = dba_open("shabbat/wap.db", "r", "db3");
    if ($id)
    {
	$val = dba_fetch($_SERVER['HTTP_X_UP_SUBNO'], $id);
	dba_close($id);
    }
}

$zip = '';
if ($val)
{
    $cookie_parts = explode('&', $val);
    for ($i = 0; $i < count($cookie_parts); $i++) {
        $parts = explode('=', $cookie_parts[$i]);
        if ($parts[0] == 'zip') {
            $zip = $parts[1];
        }
    }
}
?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
  "http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
 <card id="main" title="1-Click Shabbat">
  <do type="accept" label="OK">
   <go href="/shabbat/" method="get">
    <postfield name="zip" value="$(zip)"/>
    <postfield name="cfg" value="w"/>
    <postfield name="m" value="50"/>
   </go>
  </do>
  <p>Enter Zip: <input name="zip" format="5N" size="5" value="<?php
 echo $zip;
?>"/></p>
 </card>
</wml>
