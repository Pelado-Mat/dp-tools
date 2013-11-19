#!/opt/omni/bin/perl -w

=head1 NAME

dp-move-clients.pl - Generate a script to export/import every client in a cell

=head1 SYNOPSIS

dp-move-clients.pl C<[-export_only]> I<[client-skip-list...]>

=head1 DESCRIPTION

This program generates a script which can export/import every client in a cell.
This is a very convenient thing to do when you are migrating from one cell manager to another. On
the old cell manager you run:

  dp-move-clients.pl
  dp-move-clients.pl -export_only

Redirect each to a C<.bat> file on Windows or to a C<.sh> file on
Unix. Run the second script on the old cell manager first, and then
copy the first script to the new cell manager, and run it there.

=head1 OUTPUT

C<dp-move-clients.pl> reads through the output of C<omnicellinfo
-cell> and writes C<omnicc> commands for each one of them.

If C<-export_only> is specified, it will just output C<omnicc
-export_host> commands, otherwise there will also be a following
C<omnicc -import_host> command.

If a I<client-skip-list> is specified, it is a list of names of
servers to ignore -- no C<omnicc> command will be generated for these.


=head1 COPYRIGHT

Copyright 2013 [The Institute for Open Systems Technologies Pty Ltd.]

=head1 BUGS

If a client is unreachable then the import might fail.

It's not much good having a script to C<-export_only> if the original cell manager is down.

It doesn't handle clusters or virtualisation properly.

=cut


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }

use strict;

my $export_only = 0;

if ($ARGV[0] =~ /-export_only/) { 
  shift @ARGV;
  $export_only = 1;
}

my %skip_list = ();
foreach $_ (@ARGV) { 
  $skip_list{$_} = 1;
}

my $target_server = shift @ARGV;

my $datadir = exists $ENV{DP_DATA_DIR} ? $ENV{DP_DATA_DIR}: $ENV{DP_HOME_DIR};
my $homedir = $ENV{DP_HOME_DIR};

open(CELL_INFO, "omnicellinfo -cell |") || die "Couldn't run omnicellinfo -cell: $!";

my %vmware = ();
my %clusters = ();
my %servers = ();
my $hostname;

while (<CELL_INFO>) {
  next unless /host="([^"]*)"/;
  $hostname = $1;
  next if exists $skip_list{$hostname};
  $servers{$hostname} = 1;
}
close(CELL_INFO);

foreach $hostname (keys %servers) {
  print "omnicc -export_host $hostname\n";
  unless ($export_only) {
    print "omnicc -import_host $hostname\n";
  }
}
