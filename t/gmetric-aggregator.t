use strict;
use warnings;

use Test::More;

use FindBin '$Bin';
use Ganglia::Gmetric::PP;

my $proxy_port = 8650;
my $gmond_port = 8651;
my $aggregator_bin = "$Bin/../bin/gmetric-aggregator.pl";
my $aggregation_period = 5;

my @types = qw/ float double int8 uint8 int16 uint16 int32 uint32 /;

plan(tests => scalar @types);

# fake gmond
my $listener = IO::Socket::INET->new(
    Proto       => 'udp',
    LocalHost   => 'localhost',
    LocalPort   => $gmond_port,
    Reuse       => 1,
);

# start proxy
my $pid = fork;
die "fork failed: $!" unless defined $pid;
if (!$pid) {
    $ENV{PERL5LIB} = join ':', @INC;
    exec
        $aggregator_bin,
        '--remote-host' => 'localhost',
        '--remote-port' => $gmond_port,
        '--listen-host' => 'localhost',
        '--listen-port' => $proxy_port,
        '--period'      => $aggregation_period;
    die "exec failed: $!";
}

my $start_time = time;

# allow aggregator to start up
sleep 1;

my $gmetric = Ganglia::Gmetric::PP->new(host => 'localhost', port => $proxy_port);

my %sums;
for my $type (@types) {
    my $name = "${type}name";

    for (1..10) {
        my $value = rand 100;
        $value = int $value if $type =~ /int/;
        my $sent = $gmetric->gsend($type, $name, $value, 'things');
        $sums{$type} += $value;
    }
}

for (@types) {
    my $found = wait_for_readable($listener);
    die "can't read from self" unless $found;

    my $end_time = time;
    my $duration = $end_time - $start_time;

    $listener->recv(my $buf, 256);
    my ($type, $name, $value) = $gmetric->parse($buf);

    my $expected = $sums{$type} / $duration;
    my $deviation = abs($value - $expected) / $expected;

    ok($deviation < 1/$aggregation_period, $type); # allow for a second or so of difference
}

kill 'INT', $pid;
waitpid $pid, 0;

sub wait_for_readable {
    my $sock = shift;
    vec(my $rin = '', fileno($sock), 1) = 1;
    return select(my $rout = $rin, undef, undef, 7);
}
