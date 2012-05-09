#!perl -w

# Set your ValueSMS username and password here.
my $sms_username = "XXXXXX";
my $sms_password = "YYYYYY";

# Edit the phone book here in this array.

my %phonebook = ( "Greg" => "0408245856" );
my $default_phone_number = "0408245856";



# If you need to use a proxy, uncomment it here.T ricky though if you want get through
# a Microsoft ISA proxy -- you end up needing to use something like
# from http://cntlm.sourceforge.net/

my $proxy = undef;
#my $proxy = "http://proxy:8080/";

=head1 TITLE

omnisms.pl

=head1 SYNOPSIS

C<omnisms.pl> USER GROUP HOSTNAME STARTPID DEVNAME ...

=head1 DESCRIPTION

This program sends an SMS through the ValueSMS gateway to report on
mount requests. It can be used as a mount script for a device.

=cut

BEGIN {
  my $path;
  foreach $path (@INC) { if ($path =~ m:/lib$:) { push(@INC,"$path/perl"); } }
}
use strict;
# The Perl that comes with DataProtector doesn't include URI
# or LWP::UserAgent, unfortunately.
use URI;
use LWP::UserAgent;

my $USER=$ARGV[0];
my $GROUP=$ARGV[1];
my $HOSTNAME=$ARGV[2];
my $STARTPID=$ARGV[3];
my $DEVNAME=$ARGV[4];
my $DEVHOST=$ARGV[5];
my $DEVFILE=$ARGV[6];
my $DEVCLSS=$ARGV[7];
my $DEVCLASSNAME=$ARGV[8];
my $MEDID=$ARGV[9];
my $MEDLABEL=$ARGV[10];
my $MEDLOC=$ARGV[11];
my $POOLNAME=$ARGV[12];
my $POLICY=$ARGV[13];
my $MEDCLASS=$ARGV[14];
my $MEDCLASSNAME=$ARGV[15];
my $SESSIONKEY=$ARGV[16];

my $phonenum = $default_phone_number;
$phonenum = $phonebook{$USER} if exists $phonebook{$USER};

my $message = "Mount request on device $DEVNAME in session $SESSIONKEY.";

$message .= " requesting $MEDLABEL" if $MEDLABEL !~ /^\s*$/;
$message .= " from $MEDLOC" if $MEDLOC !~ /^\s*$/;
$message .= " in pool $POOLNAME";

$message .= "(pid=$STARTPID)";

my $url = URI->new('http://www.valuesms.com/msg.php');
$url->query_form(
  'u' => $sms_username,
  'p' => $sms_password,
  'd' => $phonenum,
  'm' => $message
);

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
# You can set a proxy here if you want to.
$ua->proxy('http',$proxy) if defined $proxy;

my $response = $ua->get($url);

die "$url error: ", $response->status_line unless $response->is_success;

