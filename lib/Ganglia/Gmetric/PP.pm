=head1 NAME

Ganglia::Gmetric::PP - Pure Perl emitter of Ganglia monitoring packets

=head1 SYNOPSIS

    my $gmetric = Ganglia::Gmetric::PP->new(host => 'localhost', port => 8649);
    $gmetric->gsend($type, $name, $value, $units, $slope, $tmax, $dmax);

=head1 DESCRIPTION

This module constructs Ganglia packets in the manner of the gmetric program and
sends them via UDP to a gmond. Though written in pure Perl with no non-core
dependencies, it tries to be quite fast.

=cut

package Ganglia::Gmetric::PP;

our $VERSION = 0.01;

use strict;
use warnings;

use IO::Socket::INET;

use base 'Exporter', 'IO::Socket::INET';

our @EXPORT_OK = qw(
    GANGLIA_VALUE_STRING
    GANGLIA_VALUE_UNSIGNED_SHORT
    GANGLIA_VALUE_SHORT
    GANGLIA_VALUE_UNSIGNED_INT
    GANGLIA_VALUE_INT
    GANGLIA_VALUE_FLOAT
    GANGLIA_VALUE_DOUBLE
    GANGLIA_SLOPE_ZERO
    GANGLIA_SLOPE_POSITIVE
    GANGLIA_SLOPE_NEGATIVE
    GANGLIA_SLOPE_BOTH
    GANGLIA_SLOPE_UNSPECIFIED
    METRIC_INDEX_TYPE
    METRIC_INDEX_NAME
    METRIC_INDEX_VALUE
    METRIC_INDEX_UNITS
    METRIC_INDEX_SLOPE
    METRIC_INDEX_TMAX
    METRIC_INDEX_DMAX
);
our %EXPORT_TAGS = (
    'all' => \@EXPORT_OK,
);

=head1 FUNCTIONS

=over 4

=item * $gmetric = Ganglia::Gmetric::PP->new(host => $host, port => $port)

Constructs a new object which talks to the specified host and port. If omitted,
they default to localhost and 8649, respectively.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %p = (host => 'localhost', port => 8649, @_);

    my $self = IO::Socket::INET->new(
        PeerAddr => $p{host},
        PeerPort => $p{port},
        Proto    => 'udp',
    );

    return bless $self, $class;
}

=item * $gmetric->gsend($type, $name, $value, $units, $slope, $tmax, $dmax)

Sends a Ganglia message. The parameters are:

=over 4

=item * $type

The type of data being sent. Must be one of these importable constants:

=over 4

=item * GANGLIA_VALUE_STRING

=item * GANGLIA_VALUE_UNSIGNED_SHORT

=item * GANGLIA_VALUE_SHORT

=item * GANGLIA_VALUE_UNSIGNED_INT

=item * GANGLIA_VALUE_INT

=item * GANGLIA_VALUE_FLOAT

=item * GANGLIA_VALUE_DOUBLE

=back

=item * $name

The name of the metric.

=item * $value

The current value of the metric.

=item * $units

A string describing the units of measure for the metric.

=item * $slope

A description of how the metric tends to change over time. Must be one of these importable constants:

=over 4

=item * GANGLIA_SLOPE_ZERO

Data is fixed, mostly unchanging.

=item * GANGLIA_SLOPE_POSITIVE

Value is always increasing (counter).

=item * GANGLIA_SLOPE_NEGATIVE

Value is always decreasing.

=item * GANGLIA_SLOPE_BOTH

Value can be anything.

=back

=item * $tmax

The maximum time in seconds between gmetric calls.

=item * $dmax

The lifetime in seconds of this metric.

=back

=cut

# exported constants. see http://code.google.com/p/embeddedgmetric/wiki/GmetricProtocol
use constant {
    GANGLIA_VALUE_STRING            => 'string',
    GANGLIA_VALUE_UNSIGNED_SHORT    => 'uint16',
    GANGLIA_VALUE_SHORT             => 'int16',
    GANGLIA_VALUE_UNSIGNED_INT      => 'uint32',
    GANGLIA_VALUE_INT               => 'int32',
    GANGLIA_VALUE_FLOAT             => 'float',
    GANGLIA_VALUE_DOUBLE            => 'double',

    GANGLIA_SLOPE_ZERO              => 0, # data is fixed, mostly unchanging
    GANGLIA_SLOPE_POSITIVE          => 1, # is always increasing (counter)
    GANGLIA_SLOPE_NEGATIVE          => 2, # is always decreasing
    GANGLIA_SLOPE_BOTH              => 3, # can be anything
    GANGLIA_SLOPE_UNSPECIFIED       => 4,

    METRIC_INDEX_TYPE               => 0,
    METRIC_INDEX_NAME               => 1,
    METRIC_INDEX_VALUE              => 2,
    METRIC_INDEX_UNITS              => 3,
    METRIC_INDEX_SLOPE              => 4,
    METRIC_INDEX_TMAX               => 5,
    METRIC_INDEX_DMAX               => 6,
};

# internal constants
use constant {
    MAGIC_ID                        => 0,
    GMETRIC_FORMAT                  => 'N(N/a*x![4])4N3',

    DEFAULT_UNITS                   => '',
    DEFAULT_SLOPE                   => 3,
    DEFAULT_TMAX                    => 60,
    DEFAULT_DMAX                    => 0,
};

sub gsend {
    my $self = shift;
    my @msg = (MAGIC_ID, @_);
    $msg[4] = DEFAULT_UNITS unless defined $msg[4];
    $msg[5] = DEFAULT_SLOPE unless defined $msg[5];
    $msg[6] = DEFAULT_TMAX  unless defined $msg[6];
    $msg[7] = DEFAULT_DMAX  unless defined $msg[7];
    $self->print(pack GMETRIC_FORMAT, @msg);
}

sub parse {
    my $self = shift;
    my @res = unpack GMETRIC_FORMAT, $_[0];
    die "bad magic" unless shift(@res) == MAGIC_ID;
    return @res;
}

1;

=back

=head1 AUTHOR

Adam Thomason, E<lt>athomason@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2009 by Six Apart, E<lt>cpan@sixapart.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
