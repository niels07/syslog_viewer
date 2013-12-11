#!/usr/bin/perl -w
use strict;
use warnings;
use CGI;
require "syslog.pm";

sub main
{
    my $syslog = new Syslog();

    $syslog->load_data() or exit 1;
    $syslog->start();
}

main();

