#!/opt/omni/bin/perl -w

BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }
use strict;
use Cwd;

=head1 NAME

mega-import.pl

=head1 SYNOPSIS

mega-import.pl I<watch-directory>

=head1 DESCRIPTION

C<mega-import.pl> watches for files in the watch-directory that end in .mcf. When it sees 
one, it checks to see if it is already known about in the DataProtector internal database. 
If it is not already in the database, it is imported.

=head1 SEE ALSO

L<mcf-all-media.pl>

=head1 COPYRIGHT

Copyright 2014 [The Institute for Open Systems Technologies Pty Ltd.]

=head1 BUGS

Only tested on Windows (but should work on Linux and HP-UX).

=cut

my $watch_directory = shift @ARGV;

die "$watch_directory not found" unless -d $watch_directory;

chdir ($watch_directory);

my %known = ();
while (1) {
  print STDERR ".";
  my $filename;
  foreach $filename (glob("*.mcf")) {
     my $medium = $filename;
     $medium =~ s/\.mcf//;
     $medium =~ s/_/:/;
     next if exists $known{$medium};
     my $exists_already = 0;
     open(EXIST_CHECK,"omnimm -media_info $medium |") || die "Can't run omnimm -media_info $medium";
     while (<EXIST_CHECK>) { if (/Medium Label/) { $exists_already = 1; } }
     close(EXIST_CHECK);
     if ($exists_already) { 
       $known{$medium} = 1; 
       print STDERR "Actually, the database already has $medium in it\n"; 
       next; 
     }
     system("omnimm","-import_from_mcf",cwd()."/".$filename,"-orig_pool");
     $known{$medium} = 2;
  }
  sleep(15);
}
