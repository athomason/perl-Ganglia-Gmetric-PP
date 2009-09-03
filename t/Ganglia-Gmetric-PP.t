# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Ganglia-Gmetric-PP.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Ganglia::Gmetric::PP') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $gmetric = Ganglia::Gmetric::PP->new(host => 'localhost', port => 1111);
ok($gmetric, 'new');
$gmetric->gsend($type, $id, $value, $unit, $slope, $tmax, $dmax);
