#!/opt/omni/bin/perl -w

=head1 NAME

pool-replicator.pl - A script to make a two cell managers have the same pools

=head1 SYNOPSIS

pool-replicator.pl C<from> I<cellmgr>

pool-replicator.pl C<to> I<cellmgr>

=head1 DESCRIPTION

When called with C<from> as the first argument, it will connect to
I<cellmgr> and fetch all pool information from it, including free pool
information. It will then create any pools which the local cell manager
does not have, and modify any that already exist to match the remote server.

When called with C<to> it works the opposite way around: the pools
from the local cell manager are recreated on the cell manager given as an argument.

=head1 REQUIREMENTS

You will need the cell console software installed on the computer running
C<pool-replicator.pl> and the user that runs it needs to have media configuration
rights on both cells.

=head1 SEE ALSO

L<device-replicator.pl>

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

sub get_pools {
  my $server;
  if ($#_ == -1) { $server = ""; } else { $server = "-server $_[0]"; }
  open(POOL_DETAILS,"omnimm -list_pools -detail $server|")
      || die "Can't run omnimm -list_pools $server: $!";
  my $current_pool = undef;
  my %pools;
  while (<POOL_DETAILS>) {
    next if /^\s*$/;
    if (/^Pool name :\s*(.*)\s*$/) { $current_pool = $1; $current_pool =~ s/\s*$//; next; }
    die "Hit line $. of output and didn't know what to do with it: $_" unless defined $current_pool;
    next unless /^([^:]*)\s*:\s*(.*)\s*$/;
    my $attr = $1;
    my $v = $2;
    $attr =~ s/^\s*//; $attr =~ s/\s*$//;
    $v =~ s/^\s*//; $v =~ s/\s*$//;
    
    $pools{$current_pool} = {} unless exists $pools{$current_pool};
    $pools{$current_pool}->{$attr} = $v;
  }
  close(POOL_DETAILS);
  return (\%pools);
}

my $my_pools;
my $other_pools;
$my_pools = get_pools();
$other_pools = get_pools($other_server);

my $source_pools;
my $target_pools;
my @source_server;
my @target_server;

if ($direction_arg eq 'from') { 
  $source_pools = $other_pools;
  $target_pools = $my_pools;
  @source_server = ("-server",$other_server);
  @target_server = ();
} else {
  $source_pools = $my_pools;
  $target_pools = $other_pools;
  @source_server = ();
  @target_server = ("-server",$other_server);
}

# Free pools first
my $p;
my $media_type;
my $age_limit;
my $max_overwrites;
my $policy;
foreach $p (keys %$source_pools) {
  next unless ($source_pools->{$p}->{"Policy"} eq 'Free pool');
  $media_type = $source_pools->{$p}->{"Media type"};
  $age_limit = $source_pools->{$p}->{"Medium age limit"};
  $age_limit =~ s/ months//;
  $max_overwrites = $source_pools->{$p}->{"Maximum overwrites"};
  if (exists $target_pools->{$p}) {
    die "Cannot modify to new media type" unless $media_type eq $target_pools->{$p}->{"Media type"};
    if ($source_pools->{$p}->{"Medium age limit"} eq $target_pools->{$p}->{"Medium age limit"} 
        && $max_overwrites == $target_pools->{$p}->{"Maximum overwrites"}) {
       print "Skipping free pool $p which is already configured identically\n";
       next;
    }
    print "Updating free pool $p\n";
    system("omnimm","-modify_free_pool",$p,$p,$age_limit,$max_overwrites,@target_server);

  } else {
    print "Creating free pool $p\n";
    system("omnimm","-create_free_pool",$p,$media_type,$age_limit,$max_overwrites,@target_server);
  }
}

# Non-free pools next
my @free_pool;
my $move_free;
my $free_raw;
foreach $p (keys %$source_pools) {
  $policy = $source_pools->{$p}->{"Policy"};
  next if ($policy eq 'Free pool');
  $media_type = $source_pools->{$p}->{"Media type"};
  $age_limit = $source_pools->{$p}->{"Medium age limit"};
  $age_limit =~ s/ months//;
  $max_overwrites = $source_pools->{$p}->{"Maximum overwrites"};
  $free_raw = $source_pools->{$p}->{"Free pool support"};
  if ($free_raw eq 'None') { 
      $move_free = "-no_move_free_media"; 
      @free_pool = ("-no_free_pool");
  } elsif ($free_raw =~ /Uses free pool \((.*)\)/) {
      @free_pool = ("-free_pool",$1);
      if ($free_raw =~ /Move free media to free pool/) {
         $move_free = "-move_free_media";
      } else { 
         $move_free = "-no_move_free_media";
      }
  } else {
    die "Cannot understand $free_raw from pool $p";
  }
  
  if (exists $target_pools->{$p}) {
      my @relevant_fields = ("Policy","Media type","Medium age limit","Maximum overwrites",
                             "Free pool support");
      my $different = 0;
      my $f;
      foreach $f (@relevant_fields) {
        $different = 1 if $source_pools->{$p}->{$f} ne $target_pools->{$p}->{$f};
      }
      unless ($different) {
        print "Not changing pool $p because it is configured identically\n";
        next;
      }
      die "Cannot modify $p to new media type" unless $media_type eq $target_pools->{$p}->{"Media type"};
      print "Updating pool $p\n";
      system("omnimm","-modify_pool",$p,$p,$policy,$age_limit,$max_overwrites,
                @free_pool,$move_free,@target_server);

  } else {
      print "Creating pool $p\n";
      system("omnimm","-create_pool",$p,$media_type,$policy,$age_limit,$max_overwrites,
                @free_pool,$move_free,@target_server);
  }
}
