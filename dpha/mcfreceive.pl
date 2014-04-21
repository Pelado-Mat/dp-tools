#!/opt/omni/bin/perl -w

=head1 NAME

mcfreceive.pl - process incoming MCF files

=head1 SYNOPSIS

mcfreceive.pl

=head1 DESCRIPTION

This script is a pair with L<mcfsend.pl>.

If you want to keep two HP DataProtector cells in sync, you need to
transfer data about each backup and copy session. L<mcfsend.pl> does this and
is normally installed as an external notification for EndOfSession.

C<mcfreceive.pl> is normally run as a scheduled task. 

I<OK, I should set up an installer option to set this up automatically.>

C<mcfreceive.pl> looks at an incoming directory (hard-coded in the script) looking
for folders C<*.ready>. It then looks at all the media being mentioned
by the C<*.mcf> files in that directory and then exports those media from the
database. (To do this it has to change the backup protection on all sessions that use that media).

Finally, once it has forgotten everything to do with that media, it
imports the MCF files, which should re-create all relevant information
about the session.


=head1 BUGS

Protected data could get lost under the following circumstances:

=over

=item * A backup object fills up one tape and then runs over into the next because the pool is set up as appendable.

=item * That session finishes and is replicated with mcfsend.pl to the other server.

=item * Another backup is run on to the second tape.

=item * That second session is replicated over to the other server

=item * C<mcfreceive.pl> has to expire the data on the first backup object in order to export the second tape.

=item * The first session will not be completely re-created by the MCF files which are imported.

=back

This appears to be a limitation of C<omnimm -import_from_mcf>

At the moment this script only works on Windows, but it won't be hard
to fix to get it to run on HP-UX or Linux. It should work with
DataProtector 6.11 or later (including version 8), but it is probably only
safe to have this kind of catalog merging in version 8 and beyond.

=head1 COPYRIGHT

Copyright 2013 [[The Institute for Open Systems Technologies Pty Ltd.]]

=cut 


# To-do: this script needs to change the protection on any objects on the media before the export will work reliably.


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }

use strict;

my $incoming = 'E:\Replication\mcf-input';

my $dname;
foreach $dname (glob("$incoming\\*.ready")) {
  print "Handling session from media in $dname\n";
  my @filenames = glob("$dname\\*.mcf");
  my %checked_media = ();
  my $f;
  my $medium_id;
  my @useful_filenames = ();
  foreach $f (@filenames) {
    #print "Considering $f\n";
    next unless $f =~ /.*\\([a-f0-9]{8})_([a-f0-9]{8})_([a-f0-9]{4})_([a-f0-9]{4})(_[A-F0-9]{7,8})?\.mcf$/i;
    push(@useful_filenames,$f);
    $medium_id = lc "$1:$2:$3:$4";
    if (exists $checked_media{$medium_id}) {
       push(@{$checked_media{$medium_id}},$f);
       next;
    } else {
       $checked_media{$medium_id} = [ $f ];
    }
    print "Do I already know about $medium_id?\n";
    open(OMNIMM,"omnimm -media_info $medium_id |") || die "Could not run omnimm -media_info $medium_id: $!";
    my $known = 0;
    while (<OMNIMM>) { $known = 1 if /Pool/; }
    close(OMNIMM);
    if ($known) {
       print "Yes, I've seen it before, so I'll export it now so that I can start afresh.\n";
       system("omnimm","-recycle",$medium_id);
       die "Failed to run omnimm -recyle $medium_id : $!" if ($? >> 8);
       system("omnimm","-export",$medium_id);
       die "Failed to run omnimm -export $medium_id : $!" if ($? >> 8);
    }
  }
  if ($#useful_filenames == -1) {
    print "No media found in $dname which matched the right filename pattern. Continuing.\n";
    next;
  }
  print "Importing from ".join(" ",@useful_filenames)."\n";
  system("omnimm","-import_from_mcf",@useful_filenames);
  print "Return code from omnimm -import_from_mcf command was $?\n";
  my $dname_archive = $dname;
  $dname_archive =~ s/\.ready/\.processed/;
  rename $dname,$dname_archive;
}
