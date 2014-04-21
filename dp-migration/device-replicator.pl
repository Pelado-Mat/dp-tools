#!/opt/omni/bin/perl -w


=head1 NAME

device-replicator.pl - A script to make a two cell managers have the same pools

=head1 SYNOPSIS

device-replicator.pl C<from> I<cellmgr>

device-replicator.pl C<to> I<cellmgr>

=head1 DESCRIPTION

When called with C<from> as the first argument, it will connect to
I<cellmgr> and fetch all device and library information from it. It
will then create any libraries and devices which the local cell
manager does not have, and modify any that already exist to match the
remote server.

When called with C<to> it works the opposite way around: the devices and libraries
from the local cell manager are recreated on the cell manager given as an argument.

=head1 REQUIREMENTS

You will need the cell console software installed on the computer running
C<device-replicator.pl> and the user that runs it needs to have media configuration
rights on both cells.

You almost definitely will want to run L<pool-replicator.pl> before you run C<device-replicator.pl>

=head1 SEE ALSO

L<pool-replicator.pl>

=head1 BUGS

Probably many. It hasn't been tested on every variation yet.

=head1 COPYRIGHT

Copyright 2013 [[The Institute for Open Systems Technologies Pty Ltd.]]

=cut 



BEGIN
{
    push(@INC, "$ENV{DP_HOME_DIR}/lib/perl");
}
END {
    if (defined $tempfilename && -e $tempfilename) {
        unlink $tempfilename;
    }
}
use strict;
use File::Temp;

my $direction_arg = shift @ARGV;
die "Usage: $0 [from|to] server" unless ($direction_arg eq 'from' or $direction_arg eq 'to');

my $other_server = shift @ARGV;

sub get_libraries_and_devices {
  my $server;
  if ($#_ == -1) { $server = ""; } else { $server = "-server $_[0]"; }
  open(OLD_LIBRARIES,"omnidownload -list_libraries $server|")
      || die "Can't run omnidownload -list_libraries $server: $!";
  my %libraries = ();
  my $required_width = undef;
  while (<OLD_LIBRARIES>) {
    if (/^(Library name.*)Host/) {
       $required_width = length $1;
       next;
    }
    next if /^==========/;
    next if /^Together : /;
    next if /^\s*$/;
    my $l = substr($_,0,$required_width);
    $l =~ s/\s*$//;
    $libraries{$l} = 1;
  }
  close OLD_LIBRARIES;


  open(OLD_DEVICES,"omnidownload -list_devices $server|")
     || die "Can't run omnidownload -list_devices $server: $!";

  my %devices = ();
  $required_width = undef;
  while (<OLD_DEVICES>) {
    if (/^(Device Name.*)Host/) {
       $required_width = length $1;
       next;
    }
    next if /^==========/;
    next if /^Together : /;
    next if /^\s*$/;
    my $l = substr($_,0,$required_width);
    $l =~ s/\s*$//;
    $devices{$l} = 1;
  }
  return (\%libraries,\%devices);
}

my $my_libraries;
my $my_devices;
my $other_libraries;
my $other_devices;
($my_libraries,$my_devices) = get_libraries_and_devices();
($other_libraries,$other_devices) = get_libraries_and_devices($other_server);

my $source_libraries;
my $source_devices;
my $target_libraries;
my $target_devices;
my @source_server;
my @target_server;

if ($direction_arg eq 'from') { 
  $source_libraries = $other_libraries;
  $source_devices = $other_devices;
  $target_libraries = $my_libraries;
  $target_devices = $my_devices;
  @source_server = ("-server",$other_server);
  @target_server = ();
} else {
  $source_libraries = $my_libraries;
  $source_devices = $my_devices;
  $target_libraries = $other_libraries;
  $target_devices = $other_devices;
  @source_server = ();
  @target_server = ("-server",$other_server);
}

my ($fh,$tempfilename) = File::Temp::tempfile();
close($fh);
#print "Will use $tempfilename\n";



my $library;
my $dev;
foreach $library (keys %$source_libraries) {
  system("omnidownload","-library",$library,"-file",$tempfilename,@source_server);
  die "Could not run omnidownload -library $library: $!" if ($? >> 8);
  if (exists $target_libraries->{$library}) {
    print "Updating library $library\n";
    system("omniupload","-modify_library",$library,"-file",$tempfilename,@target_server);
    die "Could not run omniupload -modify_library $library: $!" if ($? >> 8);
  } else {
    print "Creating library $library\n";
    system("omniupload","-create_library",$tempfilename,@target_server);
    die ("Could not run omniupload -create_library $library $tempfilename ".join(" ",@target_server).": $!") if ($? >> 8);
  }
}

foreach $dev (keys %$source_devices) {
  system("omnidownload","-device",$dev,"-file",$tempfilename,@source_server);
  die "Could not run omnidownload -device $dev: $!" if ($? >> 8);
  if (exists $target_devices->{$dev}) {
    print "Updating device $dev\n";
    system("omniupload","-modify_device",$dev,"-file",$tempfilename,@target_server);
    die "Could not run omniupload -modify_device $dev: $!" if ($? >> 8);
  } else {
    print "Creating device $dev\n";
    system("omniupload","-create_device",$tempfilename,@target_server);
    die "Could not run omniupload -create_device $dev $tempfilename: $!" if ($? >> 8);
  }
}

