#!/usr/bin/perl -w
package Syslog;

use strict;
use warnings;
use CGI;
use DBI;

my %CONFIG = (
    "db_host" => "localhost",
    "db_user" => "logger",
    "db_pass" => "<PASS>",
    "db_name" => "syslog"
);

sub new
{
    my $class = shift;
    my $cgi = new CGI();

    print $cgi->header();
    print $cgi->start_html(
        -title  => "Webline Syslog",
		-base   => 'true',
    );
    
    my $db = DBI->connect(          
        "dbi:mysql:" . $CONFIG{"db_name"},
        $CONFIG{"db_user"},
        $CONFIG{"db_pass"},
    )
    or die $DBI::errstr;

    my $self = {
        _db        => $db,
        _cgi       => $cgi,
        _hosts     => undef,
        _programs  => undef,
        _logs      => "",
        _query     => ""
    };

    bless $self, $class;
    return $self;
}

sub load_logs
{
    my $self    = shift;
    my $db      = $self->{_db};
    my $cgi     = $self->{_cgi};
    
    my $host    = $cgi->param("host");
    my $program = $cgi->param("program");
    my $grep    = $cgi->param("grep");
    my $limit   = $cgi->param("limit");

    my $query = "SELECT `msg` FROM `logs`";

    $query .= " WHERE `host` = '$host' AND `program` = '$program'";
    $query .= " AND `msg` LIKE '%$grep%'" if ($grep ne "");
    $query .= " LIMIT $limit" if ($limit =~ /^[0-9,.E]+$/);
    
    $self->{_query} = $query;

    my $sth = $db->prepare($query);
    $sth->execute() or return;

    my $logs = "";
    while (my @row = $sth->fetchrow_array())
    {
        $logs .= $row[0] . "<br />";
    }
    $self->{_logs} = ($logs eq "") ? "No Results." : $logs;
}

sub load_programs
{
    my $self = shift;
    my $cgi  = $self->{_cgi};
    my $db   = $self->{_db};
    my $host = $cgi->param("host");
    my $sth;

    $sth = $db->prepare("SELECT DISTINCT `program` FROM `logs` WHERE `host` = '$host'");
  
    $sth->execute() or return 0;
    my @programs;

    while (my @row = $sth->fetchrow_array())
    {
        push @programs, $row[0]
    }

    $self->{_programs} = \@programs;
}

sub load_data
{
    my $self = shift;
    my $cgi  = $self->{_cgi};
    my $db   = $self->{_db};
    my $sth;

    $sth = $db->prepare("SELECT DISTINCT `host` FROM `logs`");
    $sth->execute() or return 0;
    my @hosts;
    my @row;

    push @hosts, "";
    while (@row = $sth->fetchrow_array())
    {
        push @hosts, $row[0]
    }

    $self->{_hosts} = \@hosts;

  
    if ($cgi->param("view_logs"))
    {
        $self->load_logs();
    }
    
    if ($cgi->param("host"))
    {
        $self->load_programs();
    }

    return 1;
}

sub _load_settings_table
{
    my $self     = shift;
    my $cgi      = $self->{_cgi};

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
    my @programs = ($self->{_programs}) ? @{$self->{_programs}} : ();

    print $cgi->start_Tr();
    print $cgi->td("Host");
    print $cgi->td("Program");
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
        -name    => "program",
        -values  => \@programs
    );
    print $cgi->end_td();

    print $cgi->end_Tr();
    print $cgi->end_table();
}

sub print_title
{
    my $self = shift;
    my $cgi  = $self->{_cgi};
    print $cgi->div(
        { 
            -style => "width: 100%; height: 40px;" .
                      "border-bottom: 1px solid black;" .
                      "margin-bottom: 10px;" .
                      "font-weight: bold"
        },
        "Syslog viewer"
    );
}

sub start
{
    my $self = shift;
    my $cgi  = $self->{_cgi};
    my $logs = $self->{_logs};

    $self->print_title();

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
    print $cgi->start_p();
    print "Query executed: ";
    print $cgi->span(
        { -style => "color: blue; font-weight: bold;" },
        $self->{_query}
    );
    print $cgi->end_p();

    print $cgi->div(
        {
            -style => "border-top: 1px solid black;".
                      "padding-top: 10px;"
        },
        $logs
    );

    print $cgi->end_form();
    print $cgi->end_html();
}

return 1;
