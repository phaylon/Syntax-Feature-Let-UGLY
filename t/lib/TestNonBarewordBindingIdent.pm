use strict;

package TestNonBarewordBindingIdent;
use syntax 'let';

my $foo = let 23 ($x = 17) { $x };

1;
