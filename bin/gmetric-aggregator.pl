#!/usr/bin/perl

use strict;
use warnings;

use Danga::Socket;
use Data::Dumper;
use Ganglia::Gmetric::PP ':all';
use Getopt::Long;

GetOptions(
    'remote-host=s' => \(my $remote_host),
    'remote-port=s' => \(my $remote_port = 8649),
    'listen-host=i' => \(my $listen_host = '0.0.0.0'),
    'listen-port=i' => \(my $listen_port = 18649),
    'period=i'      => \(my $period = 60),
    'g|debug'       => \(my $debug),
    'help!'         => \(my $help),
);

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
    $debug && print Data::Dumper->Dump([\@sample], ['sample']);
    $metric_aggregates{ $sample[METRIC_INDEX_NAME] } += $sample[METRIC_INDEX_VALUE];
    $metric_templates{ $sample[METRIC_INDEX_NAME] } ||= \@sample;
}
Danga::Socket->AddOtherFds(fileno($listener), \&handle);

# periodically aggregate collected samples and re-emit to target gmond
sub aggregator {
    for my $metric (keys %metric_aggregates) {
        my @aggregate = @{ $metric_templates{$metric} };
        $aggregate[METRIC_INDEX_VALUE] = $metric_aggregates{$metric} / $period;
        $aggregate[METRIC_INDEX_VALUE] = int($aggregate[METRIC_INDEX_VALUE])
            if $aggregate[METRIC_INDEX_TYPE] =~ /int/;
        $aggregate[METRIC_INDEX_TMAX] = $period;
        $debug && print Data::Dumper->Dump([\@aggregate], ["${metric}_emitted"]);
        $emitter->gsend(@aggregate);
    }
    %metric_aggregates = %metric_templates = ();
    Danga::Socket->AddTimer($period, \&aggregator);
}
Danga::Socket->AddTimer($period, \&aggregator);

Danga::Socket->EventLoop;
