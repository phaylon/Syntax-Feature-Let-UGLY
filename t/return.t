use strict;
use warnings;

use Test::Most;
use syntax qw( let );

my $test = sub {

    my $val = let ( $x = $_[0], $y = $_[1] ) {

        return "inside $y" if $y;
        $x;
    };

    return "outside $val";
};

is $test->(23),     'outside 23',   'return not used';
is $test->(23, 17), 'inside 17',    'returned from sub';

done_testing;
