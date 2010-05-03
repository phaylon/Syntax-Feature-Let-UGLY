use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Most;
use syntax 'let', let => { -as => 'scoped' };


# basic stuff
is          let () { 23 },                      23,             'empty var spec';
is          let ($x) { $x },                    undef,          'default value is undef';
is_deeply   let ($x, $y) { [$x, $y] },          [undef, undef], 'multiple undefined values';
is          let ($x = 23) { $x },               23,             'simple value';
is          let ($x = 2, $y = 3) { "$x$y" },    23,             'multiple simple values';

# default binding test
do {
    my $foo = 23;
    is let ($foo = 3, $bar = $foo) { "$foo, $bar" }, '3, 23', 'default scoping binds all value expressions to outer scope';
};

# sequential binding
is          let seq ($x = 23, $y = $x) { $y },              23, 'sequential scoping';

# recursive binding
is          let rec ($x = sub { $y }, $y = 23) { $x->() },  23, 'recursive scoping';

# multiple values
is_deeply   let ($x = $y = 23) { [$x, $y] },    [23, 23],       'multiple variables';

# DWIM on different types in same declaration
do {
    is_deeply let ($count = @all = (3 .. 5)) { [$count, [@all]] }, [3, [3, 4, 5]], 'multible variables context test';
};

# renamed import
is          scoped ($x = 3) { $x * 2 },         6,              'using -as option to rename imported keyword';

# invalid binding identifier
throws_ok { 
    require TestNonBarewordBindingIdent;
} qr/variable specification/i, 'non bareword binding identifier throws error';

# no arguments
throws_ok { 
    require TestMissingArguments;
} qr/variable specification/i, 'missing arguments throws error';

# invalid variable specification
throws_ok { 
    require TestInvalidVarSpec;
} qr/variable specification/i, 'invalid variable specification throws error';

# invalid code block
throws_ok { 
    require TestInvalidCodeBlock;
} qr/code block/i, 'invalid code block throws error';

# invalid binding identifier
throws_ok { 
    require TestInvalidBindingIdent;
} qr/binding identifier.+fnord/i, 'invalid binding identifier throws error';

# invalid variable
throws_ok { 
    require TestInvalidVar;
} qr/variable.+777/i, 'invalid variable throws error';

# invalid variable expr
throws_ok { 
    require TestInvalidVarExpr;
} qr/variable.+foo\(\$x\)/i, 'invalid variable expression throws error';

# missing code block
throws_ok { 
    require TestMissingBlock;
} qr/code block/i, 'missing code block throws error';

# ignore aesthetical commata
is let ($x = 3,$z,,$y = 4,) { $x + $y }, 7, 'empty entries in variable specification';

done_testing;
