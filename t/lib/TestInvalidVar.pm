use strict;

package TestInvalidVar;
use syntax 'let';

my $foo = let (777 = 23) { 23 };

1;
