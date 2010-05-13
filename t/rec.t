use strict;
use warnings;

use Test::Most;
use syntax qw( let );

is let rec ($x = sub { $y }, $y = 23) { $x->() },  23, 'recursive scoping';

done_testing;
