create table hebcal1.hebcal_shabbat_email (
    email_address varchar(200) not null primary key,
    email_id varchar(24) not null,
    email_status varchar(16) not null,
    email_created datetime not null,
    email_updated timestamp,
    email_candles_zipcode varchar(5),
    email_candles_city varchar(20),
    email_candles_havdalah tinyint,
    email_optin_announce tinyint(1),
    unique (email_id),
    index (email_status)
);

create table hebcal1.hebcal_shabbat_bounce_address (
    bounce_id int NOT NULL auto_increment,
    bounce_address varchar(200) NOT NULL,
    bounce_std_reason varchar(16),
    bounce_timestamp timestamp,
    primary key (bounce_id),
    unique (bounce_address)
);

create table hebcal1.hebcal_shabbat_bounce_reason (
    bounce_id int NOT NULL,
    bounce_time datetime not null,
    bounce_reason varchar(200),
    index (bounce_id)
);

create table hebcal1.hebcal_zips (
    zips_zipcode varchar(5) not null primary key,
    zips_latitude varchar(12) not null,
    zips_longitude varchar(12) not null,
    zips_timezone tinyint not null,
    zips_dst tinyint(1) not null,
    zips_city varchar(64) not null,
    zips_state varchar(2) not null
);
