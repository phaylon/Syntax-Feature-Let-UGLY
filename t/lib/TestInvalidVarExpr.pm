use strict;

package TestInvalidVarExpr;
use syntax 'let';

my $foo = let (foo($x) = 23) { 23 };

1;
