#!/opt/omni/bin/perl

=head1 NAME

omniperf.pl

=head1 SYNOPSIS

omniperf.pl [sessions...]

=head1 DESCRIPTION

This program prints out the throughput rate  of the specified sessions,
or all current sessions if no sessions are specified.

It also tried to show expected time of completion.

=head1 BUGS

It only handles session numbers at the moment. It would be better if it could run based on
specifications as well.

It doesn't show expected completion time for barlist backups, which would be really useful.

This script hasn't seen enough testing to really know if it works.

=head1 COPYRIGHT

Copyright 2013 [[The Institute for Open Systems Technologies Pty Ltd.]]

=cut 


BEGIN { push(@INC,"$ENV{DP_HOME_DIR}/lib/perl"); }

use strict;
use Time::Local;


my $session_id;
my %session_objects;
my %session_type = ();
my %device_objects;

my @session_list = @ARGV;
if ($#session_list == -1) {
  open(OMNISTAT,"omnistat|") || die "Can't run omnistat: $!";
  while (<OMNISTAT>) {
     next unless m:(\d{4}/\d{2}/\d{2}-\d+)\s*(\w+):;
     if ($2 eq 'Admin' || $2 eq 'Media') { 
       next;
     }
     push(@session_list,$1);
     $session_type{$1} = $2;
  }
  close(OMNISTAT);
} else {
  foreach $session_id (@session_list) {
    open(OMNISTAT,"omnistat -session $session_id -status_only|") || die "Can't run omnistat -session $session_id: $1";
    while(<OMNISTAT>) {
      next unless m:(\d{4}/\d{2}/\d{2}-\d+)\s*(\w+):;
      $session_type{$1} = $2;
    }
    die "No such session: $session_id" unless exists $session_type{$session_id};
    close(OMNISTAT);
  } 
}

my $current_device_name;
#print STDERR "Reporting on " . join(", ",@session_list)."\n";
foreach $session_id (@session_list) {
 open(OMNISTAT,"omnistat -session $session_id -detail |") || die "Can't run omnistat -session $session_id: $!";
 my $current_object = undef;
 my $looking_at_object = 0;
 $session_objects{$session_id} = [];
 while (<OMNISTAT>) {
   next if /^\s*$/;
   if (/^Object name\s*: (.*)$/) {
     if (defined $current_object && $looking_at_object) {
        push(@{$session_objects{$session_id}},$current_object);
     };
     $current_object = { 'Object name' => $1 };
     $looking_at_object = 1;
     next;
   }
   if (/^Device name\s*: (.*)/) {
      $current_device_name = $1;
      $current_device_name =~ s/\s*$//; 
      $looking_at_object = 0;
      $device_objects{$session_id} = {} unless exists $device_objects{$session_id};
      $device_objects{$session_id}->{$current_device_name} = {};
      next;
   }

   if (/^\s*([A-Z][^:]*)\s*: (.*)$/) {
     my $k = $1;
     my $v = $2;
     $k =~ s/\s*$//;
     $v =~ s/\s*$//;
     if ($looking_at_object) {
        $current_object->{$k} = $v;
     } else {
        $device_objects{$session_id}->{$current_device_name}->{$k} = $v;
     }
   }
 }
 push(@{$session_objects{$session_id}},$current_object);
 close(OMNISTAT); 
}

# To be portable, I should print this from strftime instead of hard-coding it
my %months = ('January' => 0, 'February' => 1, 'March' => 2,
             'April' => 3, 'May' => 4, 'June' => 5,
             'July' => 6, 'August' => 7, 'September' => 8,
             'October' => 9, 'November' => 10, 'December' => 11);

sub str2timestamp {
  my $s = shift;
  return undef unless $s =~ /, (\d+) (\w+) (\d+), (\d+):(\d+):(\d+) ([ap]\.m\.)/;
  my $mday = $1;
  my $month = $months{$2};
  my $year = $3;
  my $hour = $4;
  my $minute = $5;
  my $second = $6;
  return Time::Local::timelocal($second,$minute,$hour,$mday,$month,$year);
}

sub duration_of_session_so_far {
 my $session_id = shift;
 my $dev;
 my $session_start_time = time;
 my $current_time = time;
 my $object;

 foreach $dev (keys %{$device_objects{$session_id}}) {
      my $started = $device_objects{$session_id}->{$dev}->{"Started"} ||
            die "Missing start time from $dev in $session_id";
      next if $started eq '-';
      my $start_time = str2timestamp($started);
      die "Couldn't understand $start_time (start time of $dev in $session_id)" 
             unless defined $start_time;
       if ($start_time < $session_start_time) { $session_start_time = $start_time; }
     }
 foreach $object (@{$session_objects{$session_id}}) {
    my $name = $object->{"Object name"} || die "Missing object name in session $session_id";
    my $started = $object->{"Started"} || die "Missing start time in $name in $session_id";
    my $start_time = str2timestamp($started);
    die "Couldn't understand $start_time (start time of $name in $session_id)" unless defined $start_time;
    if ($start_time < $session_start_time) { $session_start_time = $start_time; }
 }
# print STDERR "$session_id has been running for ".($current_time - $session_start_time). " seconds\n";


  return $current_time - $session_start_time;
}

sub data_written_so_far {
 my $session_id = shift;
 my $total_processed_kbytes = 0;
 my $dev;
 foreach $dev (keys %{$device_objects{$session_id}}) {
    my $done = $device_objects{$session_id}->{$dev}->{"Done"};
    next if $done eq '-';
    die "Couldn't understand $done from $dev in $session_id" unless $done =~ /^(\d+) KB/;
    #print STDERR "$session_id $dev: $done ( = $1 KB)\n";
    $total_processed_kbytes += $1;
 } 
 return $total_processed_kbytes;
}

sub speed_of_session {
 my $session_id = shift;
 my $data_written = data_written_so_far($session_id);
 my $session_duration = duration_of_session_so_far ($session_id);
 return sprintf ("%.2f",$data_written / ($session_duration * 1024.0));
}

sub session_size_prediction {
 my $session_id = shift;
 my $total_kbytes = 0;
  my $object;
 foreach $object (@{$session_objects{$session_id}}) {
    my $name = $object->{"Object name"} || die "Missing object name in session $session_id";
    my $total_size = $object->{"Total size"}  || die "Missing total size in $name in $session_id";

    # How much data do we have to process?
    if ($total_size eq '-') {
      # Can't do much. Perhaps we could look up similar past sessions?
    } else {
      die "Couldn't understand total size $total_size for $name in $session_id" 
          unless $total_size =~ /^(\d+) KB/;
      $total_kbytes += $1;
    }
  }
 return $total_kbytes;
}


foreach $session_id (@session_list) {
  my $total_processed_kbytes = 0;
  my $total_kbytes = 0;
  my $session_start_time = time;
  my $current_time = time;
  my $start_time;
  my $started;
  my $speed_mbytes_per_second = speed_of_session ($session_id);
  my $total_kbytes = session_size_prediction($session_id);

  if ($total_kbytes == 0) {
     print "$session_id: running at $speed_mbytes_per_second MB/s\n";
     next;
  }
  my $session_duration = duration_of_session_so_far($session_id);
  my $portion_finished = (data_written_so_far($session_id)) * 1.0 / $total_kbytes;
  if ($portion_finished == 0) { $portion_finished = 0.00001; }
  # Saves on div-by-zero check for next line.
  my $expected_duration = $session_duration / $portion_finished;
  my $final_time = $current_time + $expected_duration;
  my $quantity = sprintf ("%.1f",($total_kbytes / (1024.0 * 1024.0)));
  print "$session_id: expected to finish writing $quantity GB at ".(localtime $final_time). " running at $speed_mbytes_per_second MB/s\n";
# print STDERR "$session_id: $total_processed_kbytes / $total_kbytes KB in $session_duration seconds\n";
}
