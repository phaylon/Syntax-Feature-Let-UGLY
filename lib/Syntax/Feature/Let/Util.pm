use strict;
use warnings;

# ABSTRACT: Utility functions

package Syntax::Feature::Let::Util;

use Sub::Exporter -setup => {
    exports => [qw(
        split_by_operator
        grep_significant
    )],
};

sub grep_significant {
    return grep { $_->significant } @_;
}

sub split_by_operator {
    my ($op_str, @ppi) = @_;

    my @parts = ([]);

  ITEM:
    for my $item (@ppi) {

        if ($item->isa('PPI::Token::Operator')) {
            my $content = $item->content;
            
            if ($content eq $op_str) {

                push @parts, [];
                next ITEM;
            }
        }

        push @{ $parts[-1] }, $item;
    }

    return @parts;
}

1;

__END__

=func grep_significant

    my @significant = grep_significant @ppi_elements;

Takes a list of L<PPI> elements and returns only those that are significant.

=func split_by_operator

    # split by comma
    my @parts = split_by_operator ',', @ppi_elements;

Takes an operator string and a list of L<PPI> elements and returns alist of
array references. Each reference contains the items of a part that was 
separated by the operator.

=head1 DESCRIPTION

This library provides utility functions for L<Syntax::Feature::Let>. You
shouldn't have to deal with it yourself.

=head1 SEE ALSO

L<Syntax::Feature::Let>,
L<PPI>

=cut
