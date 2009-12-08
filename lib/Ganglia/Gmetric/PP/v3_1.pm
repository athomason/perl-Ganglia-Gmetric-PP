package Ganglia::Gmetric::PP::v3_1;

use strict;
use warnings;

use base 'Ganglia::Gmetric::PP';

=for comment

A gmetric UDP packet in ganglia 3.0 consists of:
* the Ganglia packet type identifier, which is the constant metric_user_defined (value 0).
* a Ganglia_gmetric_message structure

// ganglia-3.1.2/lib/gm_protocol.x
struct Ganglia_extra_data {
  string name<>;
  string data<>;
};

struct Ganglia_metadata_message {
  string type<>;
  string name<>;
  string units<>;
  unsigned int slope;
  unsigned int tmax;
  unsigned int dmax;
  struct Ganglia_extra_data metadata<>;
};

XDR strings are encoded as a big-endian 4 byte integer count of characters in
the string, followed by character data, null-padded to a multiple of 4
characters. This is encodable with the Perl pack string (N/a*x![4]).

=cut

use constant GMETRIC_FORMAT => '';
use constant {
    MAGIC_ID       => 133, # gmetric_string
    GMETRIC_FORMAT => 'N(N/a*x![4])3N3(N/a*x![4])2',
};

sub send {
    my $self = shift;
    my @msg = (Ganglia::Gmetric::PP::MAGIC_ID, @_);
    $msg[4] = Ganglia::Gmetric::PP::DEFAULT_UNITS unless defined $msg[4];
    $msg[5] = Ganglia::Gmetric::PP::DEFAULT_SLOPE unless defined $msg[5];
    $msg[6] = Ganglia::Gmetric::PP::DEFAULT_TMAX  unless defined $msg[6];
    $msg[7] = Ganglia::Gmetric::PP::DEFAULT_DMAX  unless defined $msg[7];
    $msg[8] = 0;
    $self->SUPER::send(pack GMETRIC_FORMAT, @msg);
}

sub parse {
    my @res = unpack GMETRIC_FORMAT, $_[1];
    die "bad magic" unless shift(@res) == $_[0]->MAGIC_ID;
    pop @res;
    return @res;
}

1;
