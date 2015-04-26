#!/usr/bin/env perl	
# подсходы к эскейпингу

use DBI;
use Data::Dumper;

my $dbh = DBI->connect("dbi:SQLite:dbname=foo.db","","");


my $sql = <<'END_SQL';

CREATE TABLE fablabs2 (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    address VARCHAR(150),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    website VARCHAR(50),
    fabnews_url VARCHAR(50),
    fabnews_rating VARCHAR(4),
    fabnews_subscribers VARCHAR(10)
    )
END_SQL

$dbh->do($sql);