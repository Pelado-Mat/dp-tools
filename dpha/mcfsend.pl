#!/opt/omni/bin/perl -w

=head1 NAME

mcfsend.pl - A script to export MCF files after a backup

=head1 SYNOPSIS

mcfsend.pl I<destination-path>

=head1 DESCRIPTION

If you want to keep two HP DataProtector cells in sync, you need to
transfer data about each backup and copy session. Set this script to
run as a post-exec after each backup job, or better: set this script
as an external notification for EndOfSession.

I<OK, I should make an install option for this script so that it
automatically sets up a notification.>

Don't forget to set C<SmFirstSessionOfDay> differently on the two cell
managers, and run C<omnidbutil -set_session_counter> if you don't plan
on waiting until tomorrow to start working.

Pass a path name as an argument. It will pick up SESSIONID from the environment to find the
session number and to look up what media were used.

This is a pair with C<mcfreceive.pl> which would run as a scheduled job.

=head1 EXAMPLE

C<mcfsend.pl \\otherserver\replication>

=head1 SEE ALSO

L<mcfreceive.pl>

=head1 COPYRIGHT

Copyright 2013 [The Institute for Open Systems Technologies Pty Ltd.]

=head1 BUGS

This script has only been tested on Windows. It won't be hard to change to run on Unix.

This script always dumps the MCF files in the same hard-coded directory (C<$base_dir>). This should be configurable and/or it should always
use the default and/or it should be smart enough to figure out a reasonable default.

If the remote server is down, this script never gets around to trying to copy the MCF files over again.

=cut 


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }
use strict;

my $other_side = shift @ARGV;
my $session_id = $ENV{"SESSIONID"};
my $handle = $session_id;
$handle =~ s:/:_:g;

# Next improvement: use File::Spec->catfile and catdir to 
my $base_dir = 'E:\mcf-output';
my $mcf_dir = "$base_dir\\mcf\\$handle";
mkdir $base_dir;
mkdir "$base_dir\\mcf";
mkdir $mcf_dir;

#my $other_side = '\\\\temvdp01\Replication\mcf-input';
mkdir $other_side;
mkdir "$other_side\\$handle.partial";

open(MEDIA_INFO,"omnidb -session $session_id -media |") || die "Could not run omnidb -session $session_id -media : $!";
my $header = <MEDIA_INFO>;
my $divider = <MEDIA_INFO>;
my @media;
while (<MEDIA_INFO>) {
 next unless / ([a-f0-9]{8}:[a-f0-9]{8}:[a-f0-9]{4}:[a-f0-9]{4})/;
 push(@media,$1);
}
#print "Media used: ".join(" ",@media)."\n";
if ($#media != -1) {
 system("omnimm","-copy_to_mcf",@media,"-output_directory",$mcf_dir);
 system("robocopy","/np","/zb","/e",$mcf_dir,"$other_side\\$handle.partial");
 rename "$other_side\\$handle.partial","$other_side\\$handle.ready";
}

# More Improvements: it should be made to work across Windows and Linux.
