# wp-admin-whitelist
A bash script for mutating .htaccess to manage admin/login page IP
whitelist for WordPress sites.

## Introduction
I manage a number of WordPress websites on multiple servers for multiple
clients. For many of these sites, the number of users is small.

Although Wordfence is used to provide a level of security, it has been
helpful to lock down the administrative and login pages to a small number
of whitelisted IP addresses to minimize brute force attacks. 

This script provides a consistent and uniform approach for whitelisting
IP addresses by mutating the .htaccess file for a site. The whitelist
block looks something like this.

```
# BEGIN ADMIN WHITELIST / Generated: Fri May 29 15:55:03 CDT 2020
<IfModule mod_rewrite.c>
RewriteEngine on
RewriteCond %{REQUEST_URI} ^(.*)?wp-login\.php(.*)$ [OR]
RewriteCond %{REQUEST_URI} ^(.*)?wp-admin$
RewriteCond %{REMOTE_ADDR} !^1.1.1.1$
RewriteCond %{REMOTE_ADDR} !^2.2.2.2$
RewriteRule ^(.*)$ - [R=403,L]
</IfModule>
# END ADMIN WHITELIST
```

It's posted here for convenience so that I can get to it readily. I hope
you find it useful.

## Usage

```
$ ./whitelist.sh -help
whitelist.sh: INFO: IP Whitelisting


NAME
        whitelist.sh - IP Whitelisting

SYNOPSIS
        whitelist.sh -site name [-base path] [-file name] [-add IP]* [-del IP]*
        whitelist.sh -site name [-base path] [-file name] [-purge]

DESCRIPTION
        whitelist.sh is a tool to examine, add or remove whitelisted IP addresses
        for the named site. The whitelisted IP addresses allow access to the
        admin area of the site and the login form. This tool works by mutating
        the .htaccess file for the named site. Not specifying one or more -add
        or -del arguments or the -purge argument will show you the current
        whitelist.

OPTIONS
        -help
                Show this help text.

        -site name
                The name of the website for which the whitelisting applies. This
                will be the name of a folder in the base path containing the site
                files.

        -base path
                The path that contains site folders.
                Default: /var/www/webadmin/data/www

        -file name
                The name of the .htaccess file.
                Default: .htaccess

        -add IP
                The IP address to whitelist. You can specify this argument as many
                times as you like. If there is no whitelist block it will be created.

        -del IP
                The whitelisted IP address to remove. You can specify this argument
                as many times as you like. Removing the last whitelisted IP address
                will cause the whole whitelist block to be removed.

        -purge
                The whitelist block, if it exists, will be removed.


```
