#!/opt/omni/bin/perl -w

=head1 TITLE

try-all-devices.pl

=head1 SYNOPSYS

try-all-devices.pl I<pattern> [winfs|filesystem] I<client:mountpoint> I<tree>

=head1 DESCRIPTION

This backups up the object specfied by the last three arguments to every device in the cell which matches the first argument (a 
regexp).

=head1 COPYRIGHT


(c) The Institute for Open Systems Technologies Pty Ltd 2013

=cut


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }

use strict;

my $pattern = shift;

my $kind = shift; die "Usage: $0 /pattern/ [winfs|filesystem] client:mountpoint tree" unless $kind =~ /winfs|filesystem/;
my $client_mountpoint = shift;
my $trees = shift;

open(DEVS,"omnidownload -list_devices|") || die "Couldn't run omnidownload -list_devices: $!";

my $blank = <DEVS>;
my $first_line = <DEVS>;
my $where = index($first_line,"Host");
my $break_line = <DEVS>;

#print "Taking first $where characters of each line\n";
while (<DEVS>) {
 $_ = substr($_,0,$where);
 last if $_ eq ("=" x $where);
 s/\s*//;
 unless (/$pattern/) { 
   #print "Skipping $_\n"; 
   next;
 }
 print "omnib -$kind $client_mountpoint \"Test backup for $_\" -device \"$_\" -trees $trees -protect days 1\n";
# print "$_\n";
}
close(DEVS);
