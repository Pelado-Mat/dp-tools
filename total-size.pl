#!/usr/bin/perl -w 
use strict;
my $full = 0.0;
my $incr = 0.0;
while (<>) {
  chomp;
  next if /#/;
  my @x = split(/\t/);
  next unless $#x >= 6;
  my $f = $x[5];
  print "-->$f<--\n";
  #next unless $f =~ /^\s*[0123456789.]+\s*$/;
  my $i = $x[6];
  print "    -->$i<--\n";
  #next unless $i =~ /^\s*[0-9.]+\s*$/;
  print "$_ -> FULL=$f, INCR=$i\n";
  $full += $f;
  $incr += $i;
}

print "FULL TOTAL: $full\n";
print "INCR TOTAL: $incr\n";
