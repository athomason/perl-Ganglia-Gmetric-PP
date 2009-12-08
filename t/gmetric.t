use strict;
use warnings;

use Test::More;

use Ganglia::Gmetric::PP;

my $test_port = 8650;
my $gmetric_bin = "blib/script/gmetric.pl";
$ENV{PERL5LIB} = join ':', @INC;

my @types = qw/ string float double int8 uint8 int16 uint16 int32 uint32 /;
my @versions = qw/ 3.0 3.1 /;

plan(tests => @versions * @types);

for my $version (@versions) {
    my $gmond = Ganglia::Gmetric::PP->new(
        listen_host => 'localhost',
        listen_port => $test_port,
        version     => $version,
    );

    for my $type (@types) {
        my $name = "${type}name";
        my $value = int rand 100;

        diag "$version/$type";

        system $gmetric_bin,
            '--host'    => 'localhost',
            '--port'    => $test_port,
            '--type'    => $type,
            '--name'    => $name,
            '--value'   => $value,
            '--version' => $version;

        my $found = wait_for_readable($gmond);
        die "can't read from self" unless $found;

        my @parsed = $gmond->receive;
        is_deeply([@parsed[0..2]], [$type, $name, $value], $type);
    }
}

sub wait_for_readable {
    my $sock = shift;
    vec(my $rin = '', fileno($sock), 1) = 1;
    return select(my $rout = $rin, undef, undef, 1);
}
