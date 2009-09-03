=head1 NAME

Ganglia::Gmetric::PP::XDR - Encoder/decoder of Sun RPC XDR data

=cut

package Ganglia::Gmetric::PP::XDR;

use base 'Exporter';

our @EXPORT_OK = qw(
    int32_to_xdr
    uint32_to_xdr
    float_to_xdr
    double_to_xdr
    string_to_xdr
    int16_to_xdr
    enum_to_xdr
    uint16_to_xdr
    xdr_to_int32
    xdr_to_uint32
    xdr_to_float
    xdr_to_double
    xdr_to_string
    xdr_to_int16
    xdr_to_enum
    xdr_to_uint16
);
our %EXPORT_TAGS = (
    ':all' => \@EXPORT_OK,
    ':encode' => [qw(
        int32_to_xdr
        uint32_to_xdr
        float_to_xdr
        double_to_xdr
        string_to_xdr
        int16_to_xdr
        enum_to_xdr
        uint16_to_xdr
    )],
    ':decode' => [qw(
        xdr_to_int32
        xdr_to_uint32
        xdr_to_float
        xdr_to_double
        xdr_to_string
        xdr_to_int16
        xdr_to_enum
        xdr_to_uint16
    )],
);

=for comment

XDR basic types:

int     32 bits, big endian
uint    32 bits, big endian
float   IEEE, big endian
double  IEEE, big endian
string  4 bytes of length followed by char data, padded with nulls to multiple of 4 bytes

=cut

# in 5.9 and up, endian-ness forcers are available for more types
use constant {
    XDR_INT     => 'N',
    XDR_UINT    => ($] > 5.009 ? 'l>' : 'l'),
    XDR_FLOAT   => ($] > 5.009 ? 'f>' : 'f'),
    XDR_DOUBLE  => ($] > 5.009 ? 'd>' : 'd'),
    XDR_STRING  => 'N/a*x![4]',
};

sub int32_to_xdr  { pack XDR_INT,    int $_[0] }
sub uint32_to_xdr { pack XDR_UINT,   int $_[0] }
sub float_to_xdr  { pack XDR_FLOAT,  $_[0] }
sub double_to_xdr { pack XDR_DOUBLE, $_[0] }
sub string_to_xdr { pack XDR_STRING, $_[0] }

*int16_to_xdr  = &int32_to_xdr;
*enum_to_xdr   = &int32_to_xdr;
*uint16_to_xdr = &uint32_to_xdr;

sub xdr_to_int32  { unpack XDR_INT,    $_[0] }
sub xdr_to_uint32 { unpack XDR_UINT,   $_[0] }
sub xdr_to_float  { unpack XDR_FLOAT,  $_[0] }
sub xdr_to_double { unpack XDR_DOUBLE, $_[0] }
sub xdr_to_string { unpack XDR_STRING, $_[0] }

*xdr_to_int16  = &xdr_to_int32;
*xdr_to_enum   = &xdr_to_int32;
*xdr_to_uint16 = &xdr_to_uint32;

1;
