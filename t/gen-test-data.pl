#!/usr/bin/perl

use strict;
use warnings;

my @types = qw/ string int8 uint8 int16 uint16 int32 uint32 float double /;

my %data;
for my $type (@types) {
    my $f = "type.strace";
    my $name = "${type}test";
    my $value = rand 100;
    $value = int $value if $type =~ /int/;
    system "strace -s 1024 -o $f gmetric -t $type -n $name -v $value -u things";
    open my $fh, '<', $f or die $!;
    while (<$fh>) {
        next unless /^write/;
        #write(3, "\0\0\0\0\0\0\0\6double\0\0\0\0\0\ndoubletest\0\0\0\0\0\003123\0\0\0\0\6things\0\0\0\0\0\3\0\0\0<\0\0\0\0", 64) = 64
        die "badness" unless /("[^"]+")/;
        $data{$type} = [eval $1, [$type, $name, $value]];
    }
    unlink $f;
}
use Data::Dumper;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Indent = 1;
print Dumper(\%data);
