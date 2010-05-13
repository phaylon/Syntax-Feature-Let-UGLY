use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Most;
use syntax qw( let );

# invalid binding identifier
throws_ok { 
    require TestNonBarewordBindingIdent;
} qr/binding/i, 'non bareword binding identifier throws error';

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
} qr/block/i, 'invalid code block throws error';

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
} qr/block/i, 'missing code block throws error';

throws_ok {
    my $foo = let () { (1 .. 3) };
} qr/scalar context/i, 'context mismatch';

done_testing;
