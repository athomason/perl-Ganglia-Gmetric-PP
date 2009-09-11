#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper ();
use Ganglia::Gmetric::PP ':all';
use Getopt::Long 'GetOptions';
use Time::HiRes 'time';

sub usage {
    (my $me = $0) =~ s,.*/,,;
    my $error = shift;
    print "Error: $error\n\n" if $error;
    print <<EOU;
$me $Ganglia::Gmetric::PP::VERSION

Usage: $me [OPTIONS]...

  -h, --remote-host=STRING  Remote host where gmond is running (required)
  -p, --remote-port=INT     Remote port where gmond is running. Default 8649
  -H, --listen-host=STRING  Local interface to listen on. Default 0.0.0.0
  -P, --listen-port=INT     Local UDP port to listen on. Default 18649
  -n, --period=INT          Time period in seconds between aggregations. Default 60
  -s, --suffix=STRING       Suffix to append to gmetric units. Default "/s"
  -g, --debug               Display debugging output
  --help                    Print help and exit
EOU
    exit 1;
}

Getopt::Long::Configure('no_ignore_case');
GetOptions(
    'h|remote-host=s'   => \(my $remote_host),
    'p|remote-port=i'   => \(my $remote_port    = 8649),
    'H|listen-host=s'   => \(my $listen_host    = '0.0.0.0'),
    'P|listen-port=i'   => \(my $listen_port    = 18649),
    'n|period=i'        => \(my $period         = 60),
    's|suffix=s'        => \(my $units_suffix   = '/s'),
    'g|debug'           => \(my $debug),
    'help!'             => \(my $help),
) || usage;

usage if $help;
usage('--remote-host needed') unless defined $remote_host;

my $use_anyevent;
if (eval "use AnyEvent; 1") {
    $debug && warn "Using AnyEvent\n";
    $use_anyevent = 1;
}
elsif (eval "use Danga::Socket; 1") {
    $debug && warn "Using Danga::Socket\n";
    $use_anyevent = 0;
}
else {
    die "need either AnyEvent or Danga::Socket module";
}

my $emitter = Ganglia::Gmetric::PP->new(
    host => $remote_host,
    port => $remote_port,
);

# udp server socket
my $listener = IO::Socket::INET->new(
    Proto       => 'udp',
    LocalHost   => $listen_host,
    LocalPort   => $listen_port,
    Reuse       => 1,
);

# can only aggregate numeric types
my %allowed_types = map {$_ => 1} qw/ double float int16 int32 uint16 uint32 /;

# store gmetric events as they are received
my %metric_aggregates;
my %metric_templates;
sub handle {
    # udp packet has been received
    return unless $listener->recv(my $buf, 1 << 14);

    # parse and validate gmetric packet
    my @sample = $emitter->parse($buf);
    return unless $allowed_types{ $sample[METRIC_INDEX_TYPE] };

    # aggregate sums on the fly
    $metric_aggregates{ $sample[METRIC_INDEX_NAME] } += $sample[METRIC_INDEX_VALUE];

    # keep an example copy of this metric to re-emit with aggregated values
    $metric_templates{ $sample[METRIC_INDEX_NAME] } ||= \@sample;

    $debug && warn Data::Dumper->Dump([\@sample], ['sample']);
}
my $watcher;
if ($use_anyevent) {
    $watcher = AnyEvent->io(fh => $listener, poll => 'r', cb => \&handle);
}
else {
    Danga::Socket->AddOtherFds(fileno($listener), \&handle);
}

# periodically aggregate collected samples and re-emit to target gmond
my $last_time = time;
my $timer;
sub aggregator {
    my $time = time;
    my $measured_period = $time - $last_time;
    $debug && warn "Aggregating at $time ($measured_period elapsed)\n";

    # emit for any metric seen before, even if it wasn't seen in the last period
    for my $metric (keys %metric_templates) {
        my @aggregate = @{ $metric_templates{$metric} };

        # aggregated value is rate of metric over last period
        $aggregate[METRIC_INDEX_VALUE] = ($metric_aggregates{$metric}||0) / ($measured_period||1);
        $aggregate[METRIC_INDEX_VALUE] = int($aggregate[METRIC_INDEX_VALUE])
            if $aggregate[METRIC_INDEX_TYPE] =~ /int/;

        $aggregate[METRIC_INDEX_UNITS] .= $units_suffix;
        $aggregate[METRIC_INDEX_TMAX] = $period;

        $emitter->gsend(@aggregate);
        $debug && warn Data::Dumper->Dump([\@aggregate], ["${metric}_aggregated"]);
    }
    %metric_aggregates = ();

    $last_time = $time;
    if ($use_anyevent) {
        $timer = AnyEvent->timer(after => $period, cb => \&aggregator);
    }
    else {
        Danga::Socket->AddTimer($period, \&aggregator);
    }
}

# run event loop
if ($use_anyevent) {
    $timer = AnyEvent->timer(after => $period, cb => \&aggregator);
    AnyEvent->condvar->recv;
}
else {
    Danga::Socket->AddTimer($period, \&aggregator);
    Danga::Socket->EventLoop;
}
