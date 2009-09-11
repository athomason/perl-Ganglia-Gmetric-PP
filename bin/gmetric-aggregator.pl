#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper ();
use Ganglia::Gmetric::PP ':all';
use Getopt::Long 'GetOptions';
use Time::HiRes ();

GetOptions(
    'remote-host=s' => \(my $remote_host),
    'remote-port=s' => \(my $remote_port = 8649),
    'listen-host=i' => \(my $listen_host = '0.0.0.0'),
    'listen-port=i' => \(my $listen_port = 18649),
    'period=i'      => \(my $period = 60),
    'suffix=s'      => \(my $units_suffix = '/s'),
    'g|debug'       => \(my $debug),
    'help!'         => \(my $help),
);

my $use_anyevent;
if (eval "use AnyEvent; 1") {
    $debug && warn "Using AnyEvent\n";
    $use_anyevent = 1;
    *time = sub { AnyEvent->now };
}
elsif (eval "use Danga::Socket; 1") {
    $debug && warn "Using Danga::Socket\n";
    $use_anyevent = 0;
    *time = \&Time::Hires::time;
}
else {
    die "need either AnyEvent or Danga::Socket module";
}

die "--remote-host needed" unless defined $remote_host;

my $emitter = Ganglia::Gmetric::PP->new(
    host => $remote_host,
    port => $remote_port,
);

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
    return unless $listener->recv(my $buf, 1 << 14);
    my @sample = $emitter->parse($buf);
    return unless $allowed_types{ $sample[METRIC_INDEX_TYPE] };
    $debug && warn Data::Dumper->Dump([\@sample], ['sample']);
    $metric_aggregates{ $sample[METRIC_INDEX_NAME] } += $sample[METRIC_INDEX_VALUE];
    $metric_templates{ $sample[METRIC_INDEX_NAME] } ||= \@sample;
}
my $watcher;
if ($use_anyevent) {
    $watcher = AnyEvent->io(fh => $listener, poll => 'r', cb => \&handle);
}
else {
    Danga::Socket->AddOtherFds(fileno($listener), \&handle);
}

# periodically aggregate collected samples and re-emit to target gmond
my %metrics_seen;
my $last_time = time;
my $timer;
sub aggregator {
    my $time = time;
    my $measured_period = $time - $last_time;
    $debug && warn "Aggregating at $time ($measured_period elapsed)\n";
    $metrics_seen{$_} ||= 1 for keys %metric_aggregates;
    for my $metric (keys %metrics_seen) {
        my @aggregate = @{ $metric_templates{$metric} };
        $aggregate[METRIC_INDEX_VALUE] = ($metric_aggregates{$metric}||0) / ($measured_period||1);
        $aggregate[METRIC_INDEX_VALUE] = int($aggregate[METRIC_INDEX_VALUE])
            if $aggregate[METRIC_INDEX_TYPE] =~ /int/;
        $aggregate[METRIC_INDEX_UNITS] .= $units_suffix;
        $aggregate[METRIC_INDEX_TMAX] = $period;
        $emitter->gsend(@aggregate);
        $debug && warn Data::Dumper->Dump([\@aggregate], ["${metric}_aggregated"]);
    }
    %metric_aggregates = ();
    $last_time = time;
    if ($use_anyevent) {
        $timer = AnyEvent->timer(after => $period, cb => \&aggregator);
    }
    else {
        Danga::Socket->AddTimer($period, \&aggregator);
    }
}

if ($use_anyevent) {
    $timer = AnyEvent->timer(after => $period, cb => \&aggregator);
    AnyEvent->condvar->recv;
}
else {
    Danga::Socket->AddTimer($period, \&aggregator);
    Danga::Socket->EventLoop;
}
