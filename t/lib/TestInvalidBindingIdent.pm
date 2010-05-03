use strict;

package TestInvalidBindingIdent;
use syntax 'let';

my $foo = let fnord ($x = 17) { $x };

1;
