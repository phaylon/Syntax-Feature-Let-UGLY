use strict;
use warnings;

use Test::Most;
use syntax 'let', let => { -as => 'scoped' };

#
# basic stuff
#
is let () { 23 },   23,     'empty var spec';
is let ($x) { $x }, undef,  'default value is undef';

is_deeply let ($x, $y) { 
    [$x, $y];
}, [undef, undef], 'multiple undefined values';

is let ($x = 23) { $x },               23,  'simple value';
is let ($x = 2, $y = 3) { "$x$y" },    23,  'multiple simple values';

#
# default binding test
#
do {
    my $foo = 23;
    is let ($foo = 3,
            $bar = $foo) { 
                "$foo, $bar";
            }, 
        '3, 23', 
        'default scoping binds all value expressions to outer scope';
};

# multiple values
is_deeply let ($x = $y = 23) { [$x, $y] }, [23, 23], 'multiple variables';

# multiple returned values
is_deeply [ let (@x = (1 .. 5)) { @x } ], [1 .. 5], 'multiple values returned';

# DWIM on different types in same declaration
do {
    is_deeply
        let ($count = @all = (3 .. 5)) { 
            [ $count, [ @all ] ];
        }, 
        [3, [3, 4, 5]], 
        'multible variables context test';
};

# renamed import
is scoped ($x = 3) { $x * 2 }, 6, 'using -as option to rename imported keyword';

# ignore aesthetical commata
is let ($x = 3,$z,,$y = 4,) { $x + $y }, 7, 'empty entries in variable specification';

# make sure we don't eat up too many values
do {
    my @foo = ( my $bar = let ($x = 3) { $x }, 23 );
    is_deeply \@foo, [3, 23], 'following values returned as expected';
    is $bar, 3, 'return value correctly assigned in expression';
};

done_testing;
