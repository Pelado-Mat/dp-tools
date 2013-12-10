#!/opt/omni/bin/perl -w

=head1 NAME

omniperfreport.pl

=head1 SYNOPSIS

C<omniperfreport.pl> [C<-detail>] [C<-latest>]

C<omniperfreport.pl> [C<-detail>] C<-sessions> I<sessionid...>

C<omniperfreport.pl> [C<-detail>] [C<-history> I<number-of-sessions>] C<-datalist> I<datalist...>

=head1 DESCRIPTION

This program prints out a report on DataProtector backup throughput performance.

Without C<-detail> it prints out a summary of the total data delivered and the average performance of the selected backup sessions.
With C<-detail> it also prints out the data delivered and average performance of each object in each backup session.

There are three ways of selecting which backup sessions to report on:

=over 4

=item * C<-latest> (or no argument at all) looks at the most recent backup from each backup specification saved on the cell manager

=item * C<-sessions> followed by a list of session IDs

=item * C<-datalist> followed by a list of datalist names. This will look at the 7 most recent backups using that specification, or
however many are specified with the C<-history> argument. Barlists need to be specified in the form 'BARTYPE Barlistname', such
as 'Oracle8 CustomersDB'

=back

=head1 BUGS

The C<-latest> does not show the most recent successful backup; if the backup failed, then it will skip showing it.

=head1 COPYRIGHT

Copyright 2013 (The Institute for Open Systems Technologies Pty Ltd)

=cut


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl") if exists $ENV{DP_HOME_DIR}; push(@INC,"/opt/omni/lib/perl"); }
use strict;
use Time::Local;

my %datalists;
my %datalist_of_session;
my $name;
my $backup_id;
my $session_id;

my $purpose = "latest";
my $show_object_detail = 0;
my $history_length = 7;

if ($#ARGV > -1 && $ARGV[0] =~ /-det?(ail)?/) { $show_object_detail = 1; shift @ARGV; }
if ($#ARGV > -1 && $ARGV[0] =~ /-hi(story)?/) { shift @ARGV; $history_length = shift @ARGV; }

if ($#ARGV==-1) { $purpose = "latest"; }
elsif ($ARGV[0] =~ /-l(atest)?/) { $purpose = "latest"; shift @ARGV; }
elsif ($ARGV[0] =~ /-s(essions?)?/) { $purpose = "session"; shift @ARGV; }
elsif ($ARGV[0] =~ /-d(data)?(list)?/) { $purpose = "datalist"; shift @ARGV; }
else { die "Usage: $0 -latest / -sessions [sessionid...] / -datalist [datalists...]"; }

if ($purpose eq 'latest') {
  print STDERR "Fetching list of backup specifications\n";
  open(BACKUPS,"omnicellinfo -dlinfo|") || die "Couldn't run omnicellinfo: $!";
  while (1) {
    my $t = <BACKUPS> || last;
    $name = <BACKUPS> || last;
    my $owner = <BACKUPS> || last;
    my $preexec = <BACKUPS> || last;
    my $postexec = <BACKUPS> || last;
    my $blank = <BACKUPS>;
    chomp $t;
    chomp $name;
    if ($t eq "OB2") { $datalists{"$name"} = {}; }
    else { $datalists{"$t $name"} = {}; }
  }
  close(BACKUPS);

  foreach $backup_id (keys %datalists) {
    $name = $backup_id;
    print STDERR "Searching session history for backup called $name: ";
    open(SESSIONDB,"omnidb -session -datalist \"$name\" -latest |") || die "Couldn't run omnidb -session -datalist '$name' -latest: $!";
    my $title = <SESSIONDB>;
    next unless ($title);
    my $barline = <SESSIONDB>;
    my $session_line = <SESSIONDB>;
    close(SESSIONDB);
    die "Couldn't understand session line $session_line" unless $session_line =~ m:^(\d+/\d+/\d+-\d+)\s*:;
    $session_id = $1;
    $datalists{$backup_id}->{'sessions'} = [$session_id];
    $datalist_of_session{$session_id} = $backup_id;
    print STDERR "$session_id\n";
  }
} elsif ($purpose eq 'session') {
  die "Usage: $0 -session [sessionid ...]" unless $#ARGV > -1;
  foreach $session_id (@ARGV) {
     die "Usage: $0 -session [sessionid ...]" unless $session_id =~ m:^\d+/\d+/\d+-\d+$:;
     open(OMNIRPT,"omnidb -rpt $session_id|") || die "Couldn't run omnidb -rpt $session_id: $!";
     my $s = <OMNIRPT> || die "No such session: $session_id";
     $name = <OMNIRPT>; chomp($name);
     $datalists{$name} = {} unless exists $datalists{$name};
     $datalists{$name}->{'sessions'} = [] unless exists $datalists{$name}->{'sessions'};
     push(@{$datalists{$name}->{'sessions'}},$session_id);
     $datalist_of_session{$session_id} = $name;
     close(OMNIRPT);
  }
} elsif ($purpose eq 'datalist') {
  die "Usage: $0 -datalist [datalist ...]" unless $#ARGV > -1;
  foreach $name (@ARGV) {
    print STDERR "Searching session history for backup called $name: ";
    open(SESSIONDB,"omnidb -session -datalist \"$name\"|") || die "Couldn't run omnidb -session -datalist '$name': $!";
    my $title = <SESSIONDB>;
    die "Datalist $name has never been run, are you missing the BARTYPE?" unless $title;
    my $barline = <SESSIONDB>;
    my @sessions = ();
    my $count = 0;
    while (<SESSIONDB>) { 
       my $session_line = $_;
       die "Couldn't understand session line $session_line" unless $session_line =~ m:^(\d+/\d+/\d+-\d+)\s*:;
       $session_id = $1;
       push(@sessions,$session_id);
       if ($#sessions >= $history_length) { shift(@sessions); }
       $datalist_of_session{$session_id} = $name;
       $count++;
    }
    close(SESSIONDB);
    print STDERR "found $count sessions";
    print STDERR ", using $history_length" if $history_length > $count;
    $datalists{$name} = {};
    $datalists{$name}->{'sessions'} = \@sessions;
  }
}

my %session_details;
foreach $backup_id (sort keys %datalists) {
  next unless exists $datalists{$backup_id}->{'sessions'};
  foreach $session_id (@{$datalists{$backup_id}->{'sessions'}}) {
    open(SESSION_DETAILS,"omnidb -session $session_id -detail|") || die "Couldn't run omnidb -session $session_id -detail";
    my $current_object = undef;
    my @session_objects = ();
    while (<SESSION_DETAILS>) {
      next if /^\s*$/;
      if (/^Object name\s*: (.*)$/) {
        if (defined $current_object) {
           push(@session_objects,$current_object);
        };
        $current_object = { 'Object name' => $1 };
        next;
      }
      if (/^\s*([A-Z][^:]*)\s*: (.*)$/) {
        my $k = $1;
        my $v = $2;
        $k =~ s/\s*$//;
        $v =~ s/\s*$//;
        $current_object->{$k} = $v;
      }
    }
    close(SESSION_DETAILS);
    push(@session_objects,$current_object) if defined $current_object;
    $session_details{$session_id} = \@session_objects if $#session_objects != -1;
    print STDERR "Backup session $session_id consisted of ".length(@session_objects)." objects\n";
 }
}

my %months = $^O eq 'MSWin32' ?
   qw{January 0 February 1 March 2 April 3 May 4 June 5 July 6 August 7 September 8 October 9 November 10 December 11}
 : qw{Jan 0 Feb 1 Mar 2 Apr 3 May 4 Jun 5 Jul 6 Aug 7 Sep 8 Oct 9 Nov 10 Dec 11}; 


sub str2timestamp {
  my $s = shift;
  my @save_array;
  if ($^O eq 'MSWin32') {
    return undef unless $s =~ /, (\d+) (\w+) (\d+), (\d+):(\d+):(\d+) ([ap]\.m\.)/;
    @save_array = ($1,$2,$3,$4,$5,$6,$7);
  } else {
    return undef unless $s =~ /(\d+) (\w+) (\d+) (\d+):(\d+):(\d+) ([AP]M)/;
    @save_array = ($1,$2,$3,$4,$5,$6,$7);
  }
  my $mday = $save_array[0];
  my $month = $months{$save_array[1]};
  my $year = $save_array[2];
  my $hour = $save_array[3];
  my $minute = $save_array[4];
  my $second = $save_array[5];
  if (($save_array[6] eq 'PM' || $save_array[6] eq 'p.m.') && $hour < 12) { $hour += 12; } 
  if (($save_array[6] eq 'AM' || $save_array[6] eq 'a.m.') && $hour == 12 && ($minute > 0 || $second > 0) ) { $hour = 0; }
  return Time::Local::timelocal($second,$minute,$hour,$mday,$month,$year);
}

sub populate_duration_and_speed {
  my $object = shift;
  my $long_name = $object->{'Object name'};
  if ($long_name =~ /.*'(.*)'/) { 
    $object->{'Description'} = $1;
  } else { 
    $object->{'Description'} = $long_name;
  }
  my $start = $object->{'Started'};
  my $finished = $object->{'Finished'};
  my $start_stamp = str2timestamp($start);
  my $finished_stamp = str2timestamp($finished);
  my $duration = $finished_stamp - $start_stamp;
  $object->{'Start_Stamp'} = $start_stamp;
  $object->{'Finished_Stamp'} = $finished_stamp;
  $object->{'Duration'} = $duration;
  die "Unknown timestamps: $start / $finished" unless ($start_stamp > 0 && $finished_stamp > 0);
  my $size = $object->{"Object size"};
  die "$size makes no sense as a size" unless $size =~ /^(\d+) KB/;
  my $mb = $1 / 1024.0;
  $object->{'MB'} = sprintf "%.2f",$mb;
  if ($duration != 0.0) { $object->{'Rate'} = sprintf "%8.2f",($mb / $duration); }
  else { $object->{'Rate'} = '    N/A'; }
}

my %devices;
foreach $session_id (sort keys %session_details) {
  my $object;
  $backup_id = $datalist_of_session{$session_id};
  printf "%45s",$backup_id;
  print " ($session_id): ";
  my $total_size = 0.0;
  my $earliest_start = undef;
  my $latest_finish = undef;
  foreach $object (@{$session_details{$session_id}}) {
     populate_duration_and_speed($object);
     my $device_name = $object->{'Device name'};
     $devices{$device_name} = {} unless exists $devices{$device_name};
     $devices{$device_name}->{$session_id} = [] unless exists $devices{$device_name}->{$session_id};
     push(@{$devices{$device_name}->{$session_id}},$object->{'Rate'});
     $total_size += $object->{'MB'};
     $earliest_start = $object->{'Start_Stamp'} unless defined $earliest_start;
     $latest_finish = $object->{'Finished_Stamp'} unless defined $latest_finish;
     $earliest_start = $object->{'Start_Stamp'} if ($earliest_start > $object->{'Start_Stamp'});
     $latest_finish = $object->{'Finished_Stamp'} if ($latest_finish < $object->{'Finished_Stamp'});
     if ($show_object_detail) {
        print "\n";
        printf " %50s",$object->{'Description'};
        printf " %25s",$device_name;
        print " copied ";
        printf "%8.2f",($object->{'MB'}/1024.0);
        print "GB at ".$object->{'Rate'}."MB/s";
     }
  }
  my $duration = $latest_finish - $earliest_start;
  my $rate;
  if ($duration == 0) { $rate = "N/A"; } 
  else { $rate = sprintf ("%8.2f",$total_size / $duration); }
  my $displayed_total_size = sprintf("%8.2f",$total_size / 1024.0);
  if ($show_object_detail) { print "\n Session total: "; }
  print "$displayed_total_size GB at $rate MB/s\n";
  if ($show_object_detail) { print "\n"; }
}

