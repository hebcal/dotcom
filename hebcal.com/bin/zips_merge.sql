ATTACH DATABASE '../hebcal/zips.sqlite3' AS old_zips;

SELECT COUNT(1) FROM old_zips.ZIPCodes_Primary;

CREATE TEMPORARY TABLE delta_zips
AS SELECT old.*
FROM old_zips.ZIPCodes_Primary old
LEFT JOIN ZIPCodes_Primary cur ON old.ZipCode = cur.ZipCode
WHERE cur.ZipCode IS NULL
;

SELECT * FROM delta_zips;

INSERT INTO ZIPCodes_Primary
SELECT * FROM delta_zips;

DROP TABLE delta_zips;
