use strict;
use warnings;

use Test::Most;
use syntax qw( let );

is let anddef ($x = 0) { $x }, 0, 'simple';
is scalar let anddef ($x = 2, $y, $z = 4) { 23 }, undef, 'false value';
is_deeply [ let anddef ($x = 2, @y, $z = 23) { $x } ], [], 'empty list';

done_testing;

