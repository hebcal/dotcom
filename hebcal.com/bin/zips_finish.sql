SELECT COUNT(1) FROM ZIPCodes;

INSERT INTO ZIPCodes_Primary
SELECT * FROM ZIPCodes
WHERE PrimaryRecord = 'P';

SELECT COUNT(1) FROM ZIPCodes_Primary;

INSERT INTO ZIPCodes_CityFullText
SELECT ZipCode,CityMixedCase
FROM ZIPCodes_Primary;
