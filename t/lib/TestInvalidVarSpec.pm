use strict;

package TestInvalidVarSpec;
use syntax 'let';

my $foo = let seq 23 ($x = 17) { $x };

1;
