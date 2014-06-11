#!/usr/bin/perl -w
package Syslog;

use strict;
use warnings;
use CGI;
use DBI;
use SvConf;

sub _fatal
{
    my ($self, $msg) = @_;
  
    print $self->{_cgi}->header();
    print $self->{_cgi}->start_html(
        -title  => "Syslog Error",
        -base   => "true",
    );
    print "SYSLOG ERROR: $msg";
    print $self->{_cgi}->end_html();
    exit 1;
}

sub _load_database
{
    my $self = shift;
    my $date = $self->{_cgi}->param("date");

    my $name = (($date and $date eq "now") or not $date) ? SvConf::opt("db_name") : $date;

    $self->{_db} = DBI->connect("dbi:mysql:" . $name, SvConf::opt("db_user"), SvConf::opt("db_pass"))
        or $self->_fatal("failed to connect to database: $DBI::errstr");
}

sub _load_facilities
{
    my $self = shift;
    my $host = $self->{_cgi}->param("host");

   $self->_fatal("'host' missing in POST") unless ($host);

    my $sth = $self->{_db}->prepare(
        "SELECT DISTINCT `facility` FROM `logs` WHERE `host` = '$host'"
    );
  
    $sth->execute() or return 0;
    my @fclt;

    while (my @row = $sth->fetchrow_array()) {
        push @fclt, $row[0]
    }

    $self->{_fclt} = \@fclt;
}

sub _load_dates
{
    my $self = shift;
    my (@dates, $sth);

    $sth = $self->{_db}->prepare("SHOW DATABASES WHERE `Database` LIKE '%-%-%'");
    $sth->execute() or $self->_fatal("query failed");
    push @dates, "now";

    while (my @row = $sth->fetchrow_array()) {
        push @dates, $row[0]
    }
    $self->{_dates} = \@dates;
}

sub _load_hosts
{
    my $self = shift;
    my (@hosts, $sth);
    
    $sth = $self->{_db}->prepare("SELECT DISTINCT `host` FROM `logs`");
    $sth->execute() or $self->_fatal("query failed");

    while (my @row = $sth->fetchrow_array()) {
        push @hosts, $row[0]
    }

    $self->{_hosts} = \@hosts;
}

sub _load_settings_table
{
    my $self = shift;
    my $cgi  = $self->{_cgi};

    print $cgi->start_table();
    print $cgi->start_Tr();

    print $cgi->td("Limit: ");
    print $cgi->start_td();
    print $cgi->textfield(
        -name    => "limit",
        -value   => "20",
        -size    =>  10,
    );
    print $cgi->end_td();
    
    print $cgi->end_Tr();
    print $cgi->start_Tr();
    
    print $cgi->td("Grep: ");
    print $cgi->start_td();
    print $cgi->textfield(
        -name  => "grep",
        -size  => 20
    );
    print $cgi->end_td();
    print $cgi->end_Tr();

    print $cgi->end_table();
    print $cgi->start_table();
}

sub _load_selection_table
{
    my $self     = shift;
    my $cgi      = $self->{_cgi};
    my @hosts    = @{$self->{_hosts}};
    my @fclt     = ($self->{_fclt}) ? @{$self->{_fclt}} : ();
    my @dates    = @{$self->{_dates}};

    print $cgi->start_Tr();
    print $cgi->td("Host");
    print $cgi->td("Facility");
    print $cgi->td("Date");
    print $cgi->end_Tr();

    print $cgi->start_Tr();
    print $cgi->start_td();
    print $cgi->popup_menu(
        -name     => "host",
        -values   => \@hosts,
        -onchange => "document.syslog.submit();"
    );
    print $cgi->end_td();

    print $cgi->start_td();
    print $cgi->popup_menu(
        -name    => "fclt",
        -values  => \@fclt
    );
    print $cgi->end_td();

    print $cgi->start_td();
    print $cgi->popup_menu(
        -name     => "date",
        -values   => \@dates,
        -onchange => "document.syslog.submit();"
    );
    print $cgi->end_td();

    print $cgi->end_Tr();
    print $cgi->end_table();
}

sub _load_logs
{
    my $self    = shift;
    my (%params, $logs, $sth);

    foreach my $key (qw(host fclt grep limit)) {
        my $param = $self->{_cgi}->param($key);

        if ($param) { 
            $params{$key} = $param;
        }
        elsif ($key =~ /^(host|fclt)$/) {
            $self->_fatal("'$key' missing in POST");
        }
    }

    $self->{_query}  = "SELECT `datetime`, `msg` FROM `logs` ";
    $self->{_query} .= "WHERE  `host` = '"     . $params{'host'}    . "' ";
    $self->{_query} .= "AND    `facility` = '" . $params{'fclt'} . "' ";
    $self->{_query} .= "AND     `msg` LIKE '%" . $params{'grep'}    . "%' " if ($params{'grep'} ne "");
    $self->{_query} .= "ORDER BY `datetime` DESC ";
    $self->{_query} .= "LIMIT " . $params{'limit'} . " " if ($params{'limit'} =~ /^[0-9,.E]+$/);
    
    $sth = $self->{_db}->prepare($self->{_query});
    $sth->execute() or $self->_fatal("failed to execute query: '$self->{_query}'");

    while (my @row = $sth->fetchrow_array()) {
        next if ($row[1] eq "");
        $row[1] =~ s/</&lt;/g;
        $row[1] =~ s/>/&gt;/g;
        $logs .= $self->{_cgi}->start_Tr();
        $logs .= $self->{_cgi}->td($row[0]);
        $logs .= $self->{_cgi}->td($row[1]);
        $logs .= $self->{_cgi}->end_Tr();
    }

    $self->{_logs} = ($logs eq "") 
        ? "No Results." 
        : $self->{_cgi}->start_table() . $logs . $self->{_cgi}->end_table();
}

sub _title
{
    my $self = shift;
    return $self->{_cgi}->div({ 
        -style => "width: 100%; height: 40px;" .
                  "border-bottom: 1px solid black;" .
                  "margin-bottom: 10px;" .
                  "font-weight: bold"
    }, "Syslog viewer");
}

sub new
{
    my $class = shift;
    my $self = {
        _db        => undef,
        _cgi       => new CGI(),
        _hosts     => undef,
        _fclt      => undef,
        _dates     => undef,
        _logs      => "",
        _query     => ""
    };

    bless $self, $class;
    return $self;
}

sub load_data
{
    my $self = shift;

    $self->_load_database();
    $self->_load_hosts();
    $self->_load_dates();
    $self->_load_logs() if ($self->{_cgi}->param("view_logs"));
    $self->_load_facilities() if ($self->{_cgi}->param("host"));
}

sub start
{
    my $self = shift;
    my $cgi  = $self->{_cgi};
    my $logs = $self->{_logs};

    print $self->{_cgi}->header();
    print $self->{_cgi}->start_html(
        -title  => "Syslog Viewer",
        -base   => "true",
    );

    print $self->_title();

    print $cgi->start_form(
        -name    => "syslog",
        -method  => 'POST',
        -enctype => &CGI::URL_ENCODED,
        -action  => "index.cgi"
    );
    $self->_load_settings_table();
    $self->_load_selection_table();
    print $cgi->submit(
        -name  => "view_logs" ,
        -value => "view"
    );
    print $cgi->start_p({
        -style => "font: 12px Pragmata,Courier,monospace;"
    });
    print "Query executed: ";
    print $cgi->span(
        { -style => "color: blue; font-weight: bold;" },
        $self->{_query}
    );
    print $cgi->end_p();

    print $cgi->div({
        -style => "border-top: 1px solid black;".
                  "padding-top: 10px;" .
                  "font: 10px Pragmata,Courier,monospace;"
    }, $logs);

    print $cgi->end_form();
    print $cgi->end_html();
}

1;
