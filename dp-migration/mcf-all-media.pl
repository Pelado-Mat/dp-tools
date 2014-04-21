#!/opt/omni/bin/perl -w


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }
use strict;
use File::Copy;

=head1 NAME

mcf-all-media.pl

=head1 SYNOPSIS

mcf-all-media.pl I<output-directory> I<target-server-directory> [I<target-server>]

=head1 DESCRIPTION

This program walks through everything in the media management database and writes MCF files out to the 
output directory, unless they already exist on the (optionally specified) target server. Then it copies it to
target-server-directory (with an extension of .temp, which gets changed to .mcf once it is complete).

=head1 REQUIREMENTS

The output directory must be local (this is a requirement of the C<omnimm> command).

This program uses functionality introduced in DataProtector 6.11.

=head1 SEE ALSO

L<mega-import.pl>

=head1 COPYRIGHT

Copyright 2014 [The Institute for Open Systems Technologies Pty Ltd.]

=head1 BUGS

Only tested on Windows (but should work on Linux and HP-UX).

=cut

my $output_directory = shift @ARGV;

die "$output_directory does not exist" unless -d $output_directory;

my $target_server_directory = shift @ARGV;

die "$target_server_directory does not exist" unless -d $target_server_directory;

my $target_server = undef;
$target_server = shift @ARGV if $#ARGV != -1;

my $pool;
my @pools = ();
open(POOL_LIST,"omnimm -list_pools -detail|") || die "Can't run omnimm -list_pools -detail";
while (<POOL_LIST>) {
  chomp;
  next unless /^Pool name : (.*)$/;
  $pool = $1;
  $pool =~ s/\s*$//;
  push(@pools,$pool);  
}
close(POOL_LIST);

my %media_labels = ();
my @media = ();
my $medium;
foreach $pool (@pools) {
  print "Processing $pool\n";
  open(MEDIA_LIST,"omnimm -list_pool \"$pool\" -detail |") || die "Can't run omnimm -list_media \"$pool\" -detail";
  while (<MEDIA_LIST>) {
    chomp;
    if (/Medium label\s*: (.*)/) { $media_labels{$medium} = $1; }
    next unless /^Medium identifier : (.*)$/;
    $medium = $1;
    $medium =~ s/\s*$//;
    push(@media,$medium);   
  } 
  close(MEDIA_LIST);
}

print STDERR "There appear to be ".($#media+1)." media to process.\n";
foreach $medium (reverse sort @media) {
 my $exists_already = 0;
 if (defined $target_server) {
    open(EXIST_CHECK,"omnimm -media_info $medium -server $target_server|") || die "Can't connect to $target_server";
    while (<EXIST_CHECK>) { if (/Medium Label/) { $exists_already = 1; } }
    close(EXIST_CHECK);
 }
 next if $exists_already;
 if (exists $media_labels{$medium}) { print STDERR "Exporting $media_labels{$medium}\n"; }
 else { print STDERR "Exporting media id: $medium\n"; }
 system("omnimm","-copy_to_mcf",$medium,"-output_directory",$output_directory);
 my $filename_base = $medium;
 $filename_base =~ s/:/_/g;
 print STDERR "Copying $filename_base.mcf to $filename_base.temp\n";
 File::Copy::copy("$output_directory\\$filename_base.mcf","$target_server_directory\\$filename_base.temp");
 print STDERR "Copy complete. Now renaming\n";
 rename("$target_server_directory\\$filename_base.temp","$target_server_directory\\$filename_base.mcf");
 print STDERR "Finished $medium\n";
}

