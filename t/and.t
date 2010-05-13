use strict;
use warnings;

use Test::Most;
use syntax qw( let );

is let and ($x = 3) { $x }, 3, 'simple';
is scalar let and ($x = 2, $y, $z = 4) { 23 }, undef, 'false value';
is_deeply [ let and ($x = 2, $y = 0, $z = 23) { $x } ], [], 'empty list';

done_testing;
