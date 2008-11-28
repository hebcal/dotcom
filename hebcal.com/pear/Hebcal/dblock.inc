<?php

// $Id$
// $URL$

function dba_lock_open($path, $mode, $handler) {
    $lockfile = $path . ".lock";
    $fd = fopen($lockfile, "w");
    if ($fd == false) {
	die("open($lockfile) failed");
    }
    @chmod($lockfile, 0666);

    if ($mode == "w") {
	$lockmode = LOCK_EX;
    } else {
	$lockmode = LOCK_SH;
    }

    if (flock($fd, $lockmode) == false) {
	die("flock($fd,$lockmode) failed for $lockfile");
	fclose($fd);
    }

    $id = dba_open($path, $mode, $handler);
    return array($id, $fd);
}

function dba_lock_close($id, $fd) {
    dba_sync($id);
    dba_close($id);
    flock($fd, LOCK_UN);
    fclose($fd);
}

?>
