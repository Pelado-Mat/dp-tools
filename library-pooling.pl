#!/opt/omni/bin/perl -w

=head1 TITLE

library-pooling.pl

=head1 SYNOPSIS

library-pooling.pl I<repository> I<media_pool1> I<last_slot_number_for_pool1> I<media_pool2>

=head1 DESCRIPTION

This program files media in a tape library into one of two media pools, based on their slot number.

=head1 COPYRIGHT

(c) The Institute for Open Systems Technologies Pty Ltd 2013

=cut

BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }

use strict;
my $repository = shift;
my $media_pool1 = shift;
my $last_slot_for_1 = shift;
my $media_pool2 = shift;

open (LISTING,"omnimm -repository $repository |") || die "Couldn't run omnimm -repository $repository: $!";
while (<LISTING>) {
  chomp;
  next unless /^(\d+)\s/;
  my $slot = $1;
  s/^[^[]*\[//;
  s/\].*$//;
  print "omnimm -move_medium $_ ";
  print qq{"$media_pool1"} if $slot <= $last_slot_for_1;
  print qq{"$media_pool2"} if $slot > $last_slot_for_1;
  print "\n";
}
close(LISTING);
