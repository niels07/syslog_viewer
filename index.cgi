#!/usr/bin/perl -w
use strict;
use warnings;
use CGI;
require "Syslog.pm";

sub main
{
    my $syslog = new Syslog();
    $syslog->load_data();
    $syslog->start();
}

main();

