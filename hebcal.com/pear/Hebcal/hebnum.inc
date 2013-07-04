<?php

/***********************************************************************
 * Convert decimal dates to Hebrew
 *
 * Copyright (c) 2013  Michael J. Radwin.
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
 **********************************************************************/

$hebnum_numbers = array(
    1 => "\327\220",
    2 => "\327\221",
    3 => "\327\222",
    4 => "\327\223",
    5 => "\327\224",
    6 => "\327\225",
    7 => "\327\226",
    8 => "\327\227",
    9 => "\327\230",
    10 => "\327\231",
    20 => "\327\233",
    30 => "\327\234",
    40 => "\327\236",
    50 => "\327\240",
    60 => "\327\241",
    70 => "\327\242",
    80 => "\327\244",
    90 => "\327\246",
    100 => "\327\247",
    200 => "\327\250",
    300 => "\327\251",
    400 => "\327\252",
    );

$hebnum_months = array(
    "Nisan"     => "\327\240\326\264\327\231\327\241\326\270\327\237",
    "Iyyar"     => "\327\220\326\264\327\231\326\270\327\231\327\250",
    "Sivan"     => "\327\241\326\264\327\231\327\225\326\270\327\237",
    "Tamuz"     => "\327\252\326\274\326\270\327\236\327\225\326\274\327\226",
    "Av"        => "\327\220\326\270\327\221",
    "Elul"      => "\327\220\326\261\327\234\327\225\326\274\327\234",
    "Tishrei"   => "\327\252\326\274\326\264\327\251\327\201\326\260\327\250\326\265\327\231",
    "Cheshvan"  => "\327\227\326\266\327\251\327\201\326\260\327\225\326\270\327\237",
    "Kislev"    => "\327\233\326\274\326\264\327\241\326\260\327\234\326\265\327\225",
    "Tevet"     => "\327\230\326\265\327\221\326\265\327\252",
    "Sh'vat"    => "\327\251\327\201\326\260\327\221\326\270\327\230",
    "Adar"      => "\327\220\326\267\327\223\326\270\327\250",
    "Adar I"    => "\327\220\326\267\327\223\326\270\327\250 \327\220\327\263",
    "Adar II"   => "\327\220\326\267\327\223\326\270\327\250 \327\221\327\263",
    );

function hebnum_to_array($num)
{
    $result = array();

    $num = $num % 1000;

    while ($num > 0)
    {
	$incr = 100;

	if ($num == 15 || $num == 16)
	{
	    $result[] = 9;
	    $result[] = $num - 9;
	    break;
	}

	for ($i = 400; $i > $num; $i -= $incr)
	{
	    if ($i == $incr)
	    {
		$incr = (int) ($incr / 10);
	    }
	}

	$result[] = $i;

	$num -= $i;
    }

    return $result;
}

function hebnum_to_string($num)
{
    global $hebnum_numbers;

    $arr = hebnum_to_array($num);
    $digits = count($arr);

    if ($digits == 1)
    {
	$result = $hebnum_numbers[$arr[0]] . "\327\263"; # geresh
    }
    else
    {
	$result = "";
	for ($i = 0; $i < $digits; $i++)
	{
	    if (($i + 1) == $digits) {
		$result .= "\327\264"; # gershayim
	    }
	    $result .= $hebnum_numbers[$arr[$i]];
	}
    }

    return $result;
}


function build_hebrew_date($hm, $hd, $hy)
{
    global $hebnum_months;

    $vowel = "\326\260"; # Sheva U+05B0
    $month_prefix = " \327\221\326\274";
    if ($hm == "Sh'vat") {
	$vowel = "\326\264"; # Hiriq U+05B4
    }
    return hebnum_to_string($hd) . $month_prefix . $vowel .
        $hebnum_months[$hm] . " " . hebnum_to_string($hy);
}

?>