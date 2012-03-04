<?php
/**
 * The base configurations of the WordPress.
 *
 * This file has the following configurations: MySQL settings, Table Prefix,
 * Secret Keys, WordPress Language, and ABSPATH. You can find more information
 * by visiting {@link http://codex.wordpress.org/Editing_wp-config.php Editing
 * wp-config.php} Codex page. You can get the MySQL settings from your web host.
 *
 * This file is used by the wp-config.php creation script during the
 * installation. You don't have to use the web site, you can just copy this file
 * to "wp-config.php" and fill in the values.
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('WP_CACHE', true); //Added by WP-Cache Manager
define('DB_NAME', 'hebcal_com');

/** MySQL database username */
define('DB_USER', 'hebcalcom');

/** MySQL database password */
define('DB_PASSWORD', 'xxxxxxxx');

/** MySQL hostname */
define('DB_HOST', 'mysql5.hebcal.com');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         'VJeWEo+,-B!V7~iXM]+IM0<~Q83gxuZ2~}rK1Fg,/t[P,fP8s|?m(4G=z?q3[k7K');
define('SECURE_AUTH_KEY',  'H~IL!D=joG%GW[}cb+mF8<{p2/+=a&wIxqp+oyL|9EH5FIo.Od NSW/S=!IVm38B');
define('LOGGED_IN_KEY',    '7U{1K9?=Ym51gNp&+k(#~qzC@?<MEb&P5T|dF/OX`,cpwS,YDI>`3~fK#2:Ev7N{');
define('NONCE_KEY',        '&Mb1uo<qr5~^|pe&Zex|3c11}L9M$ZB&+*E1/m|i[A!VC5f*;*b2TqlwP-;mu$V9');
define('AUTH_SALT',        '%(ayJ9P%5Qe*HupFE?;a-w/^-_+i5gfK|pNC8(m|-r5P =]f?tugWEOSK?:KB2|R');
define('SECURE_AUTH_SALT', '~L6tJz 1wb^9.w7+Yyb,-pc:;w+PXg&#Be!-j`TBLivM?AFH{dwzOyET-wPq,<TQ');
define('LOGGED_IN_SALT',   'SSr0/H}5{hd<o`oir,ll a;z9b9>o=E<iPDEyW6H3JR*j O|%Sj?eHum?Y -<k|A');
define('NONCE_SALT',       '`{mc$}(yPh&A%oQ+qNI0u_UWK>FH~`mYm&rq$x<q0SE6.a|4tD+g$^N4~gGVCBG|');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each a unique
 * prefix. Only numbers, letters, and underscores please!
 */
$table_prefix  = 'wp_wyfawl_';

/**
 * WordPress Localized Language, defaults to English.
 *
 * Change this to localize WordPress. A corresponding MO file for the chosen
 * language must be installed to wp-content/languages. For example, install
 * de_DE.mo to wp-content/languages and set WPLANG to 'de_DE' to enable German
 * language support.
 */
define('WPLANG', '');

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 */
define('WP_DEBUG', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
