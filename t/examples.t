use strict;
use warnings;

use Test::Most;
use syntax qw( let );

do {
    my $even_amount = let rec (
        $even   = sub { $_[0] == 0 ? 1 : $odd->($_[0] - 1) },
        $odd    = sub { $_[0] == 0 ? 0 : $even->($_[0] - 1) },
    ) {
        $even->(42);
    };

    is $even_amount, 1, 'synopsis rec example';
};

do {
    my $num = let seq ($x = 3, $y = $x * $x) {
        $x + $y;
    };

    is $num, 12, 'synopsis seq example';
};

done_testing;
