<?php 
/* 
 * create a SQLite3 handle. 
 * 
 * Note: in-memory database are created by the magic keyword ":memory:" 
 * 
 */ 

$db = sqlite3_open(":memory:"); 
if (!$db) die ("Could not create in-memory database.."); 

/* 
 * create a simple test and insert some values.. 
 */ 

$ret = sqlite3_exec ($db, "CREATE TABLE test (id INTEGER, name TEXT, age INTEGER);"); 
if (!$ret) die (sqlite3_error($db)); 

sqlite3_exec($db, "INSERT INTO test (id,name,age) VALUES (1,'michael',32)"); 
sqlite3_exec($db, "INSERT INTO test (id,name,age) VALUES (2,'bob',27)"); 
sqlite3_exec($db, "INSERT INTO test (id,name,age) VALUES (3,'martin',12)"); 

/* 
 * Create a query 
 */ 

$query = sqlite3_query($db, "SELECT * FROM test ORDER BY age DESC"); 
if (!$query) die (sqlite3_error($db)); 

/* 
 * sqlite3_fetch_array() returns an associative array 
 * for each row in the result set. Key indexes are 
 * the columns names. 
 */ 

while ( ($row = sqlite3_fetch_array($query))) 
{ 
        printf("%-20s %u\n", $row['name'], $row['age']); 
} 

/* 
 * do not forget to release all handles ! 
 */ 

sqlite3_query_close($query); 
sqlite3_close ($db); 
?>
