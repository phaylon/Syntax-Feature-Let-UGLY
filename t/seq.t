use strict;
use warnings;

use Test::Most;
use syntax qw( let );

is let seq ($x = 23, $y = $x) { $y }, 23, 'sequential scoping';

done_testing;
