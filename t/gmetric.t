use strict;
use warnings;

use Test::More;

use FindBin '$Bin';
use Ganglia::Gmetric::PP;

my $test_port = 8650;
my $gmetric_bin = "$Bin/../bin/gmetric.pl";
$ENV{PERL5LIB} = join ':', @INC;

my $gmetric = Ganglia::Gmetric::PP->new(host => 'localhost', port => $test_port);

my @types = qw/ string float double int8 uint8 int16 uint16 int32 uint32 /;

plan(tests => scalar @types);

my $listener = IO::Socket::INET->new(
    Proto       => 'udp',
    LocalHost   => 'localhost',
    LocalPort   => $test_port,
    Reuse       => 1,
);

for my $type (@types) {
    my $name = "${type}name";
    my $value = int rand 100;

    system $gmetric_bin,
        '--host'  => 'localhost',
        '--port'  => $test_port,
        '--type'  => $type,
        '--name'  => $name,
        '--value' => $value;

    my $found = wait_for_readable($listener);
    die "can't read from self" unless $found;

    $listener->recv(my $buf, 256);
    my @parsed = $gmetric->parse($buf);
    is_deeply([@parsed[0..2]], [$type, $name, $value], $type);
}

sub wait_for_readable {
    my $sock = shift;
    vec(my $rin = '', fileno($sock), 1) = 1;
    return select(my $rout = $rin, undef, undef, 1);
}
