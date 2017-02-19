create table hebcal_shabbat_email (
    email_address varchar(200) not null primary key,
    email_id char(24) not null,
    email_status varchar(16) not null,
    email_created datetime not null,
    email_updated timestamp,
    email_candles_zipcode varchar(5),
    email_candles_city varchar(20),
    email_candles_geonameid int,
    email_candles_havdalah tinyint,
    email_optin_announce tinyint(1),
    email_ip varchar(16),
    unique (email_id),
    index (email_status)
);

create table hebcal_shabbat_bounce (
    id int NOT NULL auto_increment PRIMARY KEY,
    email_address varchar(200) NOT NULL,
    timestamp timestamp NOT NULL,
    std_reason varchar(16),
    full_reason text,
    deactivated tinyint(1) NOT NULL
);
