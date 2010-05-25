use inc::Module::Install;

name            'Ganglia-Gmetric-PP';
all_from        'lib/Ganglia/Gmetric/PP.pm';

test_requires   'AnyEvent'                      => 0;

WriteAll;
