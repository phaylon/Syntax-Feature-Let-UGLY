use strict;

package TestInvalidCodeBlock;
use syntax 'let';

my $foo = let ($x = 17) 23 { $x };

1;
