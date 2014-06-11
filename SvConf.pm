 #!/usr/bin/perl -w

package Svconfig;

use strict;
use warnings;

use Exporter;

our @ISA = qw/ Exporter /;
our @EXPORT = qw(opt);

my %config = (
    # Hostname for database.
    "db_host" => "localhost",

    # Database owner.
    "db_user" => "logger",

    # Password for database owner.
    "db_pass" => "<PASS>",

    # Name of the database for today.
    "db_name" => "syslog"
);

sub opt
{
    my $key = shift;
    return $config{$key};
}

1;


