<?php 
/* 
 * create a SQLite3 handle. 
 * 
 * Note: in-memory database are created by the magic keyword ":memory:" 
 * 
 */ 

$db = new SQLite3(":memory:");
if (!$db) die ("Could not create in-memory database.."); 

/* 
 * create a simple test and insert some values.. 
 */ 

$ret = $db->exec("CREATE TABLE test (id INTEGER, name TEXT, age INTEGER);"); 
if (!$ret) die ($db->lastErrorMsg());

$db->exec("INSERT INTO test (id,name,age) VALUES (1,'michael',32)"); 
$db->exec("INSERT INTO test (id,name,age) VALUES (2,'bob',27)"); 
$db->exec("INSERT INTO test (id,name,age) VALUES (3,'martin',12)"); 

/* 
 * Create a query 
 */ 

$query = $db->query("SELECT * FROM test ORDER BY age DESC"); 
if (!$query) die ($db->lastErrorMsg());

/* 
 * sqlite3_fetch_array() returns an associative array 
 * for each row in the result set. Key indexes are 
 * the columns names. 
 */ 

while ( ($row = $query->fetchArray()))
{ 
        printf("%-20s %u\n", $row['name'], $row['age']); 
} 

/* 
 * do not forget to release all handles ! 
 */ 
unset($query);
$db->close();
unset($db);

?>
