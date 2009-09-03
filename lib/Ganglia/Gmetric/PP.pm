=head1 NAME

Ganglia::Gmetric::PP - Pure Perl emitter of Ganglia monitoring packets

=head1 SYNOPSIS

    my $gmetric = Ganglia::Gmetric::PP->new(host => 'localhost', port => 1950);
    $gmetric->gsend($type, $id, $value, $unit, $slope, $tmax, $dmax);

=head1 DESCRIPTION

This module constructs Ganglia packets in the manner of the gmetric program and
sends them via UDP to a gmond. Though written in pure Perl with no non-core
dependencies, it tries to be quite fast.

=cut

package Ganglia::Gmetric::PP;

our $VERSION = 0.01;

use strict;
use warnings;

use Ganglia::Gmetric::PP::XDR ':all';
use IO::Socket::INET;

use base 'Exporter';

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
);

=head1 FUNCTIONS

=over 4

=item * $gmetric = Ganglia::Gmetric::PP->new(host => $host, port => $port)

Constructs a new object which talks to the specified host and port. If omitted,
they default to localhost and 1950, respectively.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %p = (host => 'localhost', port => 1950, @_);

    my $self = IO::Socket::INET->new(
        PeerAddr => $p{host},
        PeerPort => $p{port},
        Proto    => 'udp',
    );

    return bless $self, $class;
}

# see http://code.google.com/p/embeddedgmetric/wiki/GmetricProtocol
use constant {
    GANGLIA_VALUE_STRING            => string_to_xdr('string'),
    GANGLIA_VALUE_UNSIGNED_SHORT    => string_to_xdr('uint16'),
    GANGLIA_VALUE_SHORT             => string_to_xdr('int16'),
    GANGLIA_VALUE_UNSIGNED_INT      => string_to_xdr('uint32'),
    GANGLIA_VALUE_INT               => string_to_xdr('int32'),
    GANGLIA_VALUE_FLOAT             => string_to_xdr('float'),
    GANGLIA_VALUE_DOUBLE            => string_to_xdr('double'),

    GANGLIA_SLOPE_ZERO              => enum_to_xdr(0), # data is fixed, mostly unchanging
    GANGLIA_SLOPE_POSITIVE          => enum_to_xdr(1), # is always increasing (counter)
    GANGLIA_SLOPE_NEGATIVE          => enum_to_xdr(2), # is always decreasing
    GANGLIA_SLOPE_BOTH              => enum_to_xdr(3), # can be anything
    GANGLIA_SLOPE_UNSPECIFIED       => enum_to_xdr(4),
};

=item * $gmetric->gsend($type, $id, $value, $unit, $slope, $tmax, $dmax)

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

=item * $id

The name of the metric.

=item * $value

The current value of the metric.

=item * $unit

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

sub gsend {
    $_[0]->send(join '',
        "\0\0\0\0",           # magic
        $_[1],                # type name
        string_to_xdr($_[2]), # name
        string_to_xdr($_[3]), # value
        string_to_xdr($_[4]), # units
        $_[5],                # slope
        uint32_to_xdr($_[6]), # tmax
        uint32_to_xdr($_[7]), # dmax
    );
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
