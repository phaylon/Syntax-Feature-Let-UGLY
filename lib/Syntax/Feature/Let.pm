use strict;
use warnings;

# ABSTRACT: Scoped declaration of lexical variables

package Syntax::Feature::Let;

use Carp                        qw( confess );
use Devel::Declare              ();
use Syntax::Feature::Let::Util  qw( :all );
use Sub::Install                qw( install_sub );
use B::Hooks::EndOfScope;

use aliased 'Devel::Declare::Context::Simple',  'Context';
use aliased 'PPI::Token::Symbol',               'Symbol';
use aliased 'PPI::Document',                    'Document';

use namespace::clean;

$Carp::Internal{ +__PACKAGE__ }++;
$Carp::Internal{ 'Devel::Declare' }++;

sub install {
    my ($class, %args) = @_;

    # passed information
    my $target  = $args{into};
    my $options = $args{options};
    my $name    = $options->{ -as } || 'let';

    # install keyword handler
    Devel::Declare->setup_for(
        $target => {
            $name => {
                const => sub {
                    ( my $ctx = Context->new )->init(@_);
                    return $class->_transform($ctx, $options);
                },
            },
        },
    );

    # pickup function for the values
    install_sub {
        into    => $target,
        as      => $name,
        code    => sub { 

            confess sprintf q!%s called in scalar context but more than one value (%d) was returned!,
                $name,
                scalar(@_)
              if @_ > 1 and not wantarray;

            return wantarray ? @_ : shift;
        },
    };

    on_scope_end {
        namespace::clean->clean_subroutines($target, $name);
    };

    return 1;
}

sub _transform {
    my ($class, $ctx, $options) = @_;

    # skip the keyword
    $ctx->skip_declarator;

    # optional scoping type specified via bareword
    my $scoping_type = $ctx->strip_name;

    # required variable specification
    my $variable_spec = $ctx->strip_proto;

    unless (defined $variable_spec) {

        confess sprintf q!Expected variable specification after %s!,
            $scoping_type 
            ? sprintf(q!scoping type declaration '%s'!, $scoping_type)
            : sprintf(q!keyword '%s'!,                  $ctx->declarator);
    }

    # deparse the variable spec into a useful structure
    my ($statement, $doc) = $class->_inflate_statement($variable_spec);
    my $variable_ast = $class->_deparse_var_spec($statement);

    # build variable declaration code
    my $block_count = 0;
    my $declarations = $class->_render_var_spec(
        $scoping_type || 'default',
        $variable_ast,
        \$block_count,
    );

    # transform block
    $class->_block_injection($ctx, $declarations, $block_count);

#    warn "LINE " . $ctx->get_linestr;
    return 1;
}

sub _block_injection {
    my ($class, $ctx, $declarations, $block_count) = @_;

    # make sure we are followed by a block
    $ctx->skipspace;

    my $peeked = $class->_peek_char($ctx);
    unless ($peeked eq '{') {
        confess q!Expected block following variable declaration!;
    }

    # turn our block into a 'do' block
    $class->_inject($ctx, '(do ');

    # put variable declarations inside the block
    # the empty list is to default to an empty list
    $class->_inject(
        $ctx,
          $declarations
        . qq!;BEGIN { $class->_finalise_block($block_count) }!
        . q!;();!,
        1,
    );

    return 1;
}

sub _finalise_block {
    my ($class, $block_count) = @_;
        
    my $end = join('', q!}! x $block_count, q!)!);

    # close the list after the block ended
    on_scope_end {
        my $line   = Devel::Declare::get_linestr;
        my $offset = Devel::Declare::get_linestr_offset;
        substr( $line, $offset, 0 ) = $end;
        Devel::Declare::set_linestr $line;
    };
}

sub _inject {
    my ($class, $ctx, $code, $skipped) = @_;

    $skipped ||= 0;

    # insert code
    my $line = $ctx->get_linestr;
    substr( $line, $ctx->offset + $skipped, 0 ) = $code;
    $ctx->set_linestr($line);

    # jump behind inserted code, remember skipped chars
    $ctx->inc_offset(length($code) + $skipped);

    return 1;
}

sub _peek_char {
    my ($class, $ctx) = @_;

    return substr $ctx->get_linestr, $ctx->offset, 1;
}

sub _inflate_statement {
    my ($class, $body) = @_;

    # build document and isolate statement
    my $doc         = Document->new(\"$body");
    my $statement   = $doc->schild(0);

    # document is carried on so it won't GC
    return $statement, $doc;
}

sub _deparse_var_spec {
    my ($class, $var_spec) = @_;

    # no variables. makes no sense, but who cares?
    return () 
        unless $var_spec;

    # separate variable declaration expression by comma
    my @declarations = split_by_operator ',', $var_spec->children;

    # parsed list of declaration elements
    return [ map $class->_deparse_var_declaration($_), @declarations ];
}

sub _deparse_var_declaration {
    my ($class, $declaration) = @_;

    my @parts = split_by_operator '=', @$declaration;
    
    my (@vars, $expr);

    # nothing in there
    if (@parts == 1 and not @{ $parts[0] }) {
        
        return ();
    }

    # var only spec: $x
    elsif (@parts == 1) {

        @vars = @parts;
    }

    # more than one var
    else {

        $expr = pop @parts;
        @vars = @parts;
    }

    # builds a var spec with a list of lexicals, and a list of value expr tokens
    return [
        [ map {

            # only care for significant items in the variable position
            my @items = grep_significant @$_;

            confess sprintf q(Expected variable identifier, not '%s'), join '', @$_
                unless @items == 1 and $items[0]->isa(Symbol);

            $items[0];

        } @vars ],
        defined($expr) 
            ? $expr 
            : [ '()' ],
    ];
}

sub _render_var_spec {
    my ($class, $type, $variables, $block_count_ref) = @_;

    # delegation method
    my $handler = "_render_${type}_declaration";

    confess qq(Unknown variable declaration binding identifier '$type')
        unless $class->can($handler);

    return $class->$handler($variables, $block_count_ref);
}

sub _render_rec_declaration {
    my ($class, $variables) = @_;

    # all variables are declared before any value is bound
    return sprintf('my (%s); %s',

        # lexicals
        join(', ', map {
            my ($lexicals, $expr) = @$_;

            (@$lexicals);

        } @$variables),

        # assign values to lexicals
        join('; ', map {
            my ($lexicals, $expr) = @$_;

            sprintf '(%s)', join ' = ', 
                @$lexicals,
                sprintf '(%s)', join '', @$expr;

        } @$variables),
    );
}

sub _render_and_declaration {
    my ($class, $variables, $block_count_ref, $wrapper) = @_;

    $wrapper ||= sub { sprintf 'not(%s)', shift };

    return join '; ', map {
        my ($lexicals, $expr) = @$_;

        $$block_count_ref++;
        sprintf q!(%s); (%s) ? () : do {!,
            join(' = ',
                (map "my $_", @$lexicals),
                sprintf '(%s)', join '', @$expr,
            ),
            join(' or ',
                map $wrapper->($_), @$lexicals,
            );

    } @$variables;
}

sub _render_anddef_declaration {
    my ($class, $variables, $block_count_ref) = @_;

    my $wrapper = sub {
        my $is_scalar = ($_[0] =~ m{ \A \$ }x);
        
        return "not(defined $_[0])"
            if $is_scalar;

        return "not($_[0])";
    };

    return $class->_render_and_declaration($variables, $block_count_ref, $wrapper);
}

sub _render_seq_declaration {
    my ($class, $variables) = @_;

    # each variable is available to the next
    return join '; ', map {
        my ($lexicals, $expr) = @$_;

        sprintf '(%s)', join ' = ', 
            (map "my $_", @$lexicals),
            sprintf '(%s)', join '', @$expr;

    } @$variables;
}

sub _render_default_declaration {
    my ($class, $variables) = @_;

    # only outer variables are available during initialisation
    return join ' and ', map {
        my ($lexicals, $expr) = @$_;

        sprintf '((%s), 1)', join ' = ', 
            (map "my $_", @$lexicals),
            sprintf '(%s)', join '', @$expr;

    } @$variables;
}

1;

__END__

=method install

Called by the L<syntax> extension dispatcher to install the keyword in the
requesting namespace.

=option -as

    use syntax let => { -as => 'scoped' };

    my $y = scoped ($x = 3) { $x * $x };

Enables you to install the extension under a different name.

=head1 SYNOPSIS

    use syntax 'let';

    # normal binding
    my $sum = let ($x = 3, $y = 4) {
        $x + $y;
    };

    # sequential binding
    my $num = let seq ($x = 3, $y = $x * $x) {
        $x + $y;
    };

    # stop if any var is false
    my $from_cache = let and ($obj = get_obj()) { 
        $obj->value;
    };

    # stop if any scalar is undefined or any other is false
    my $count = let anddef ($c1 = $obj->count1, $c2 = $obj->count2) {
        $c1 + $c2;
    };

    # recursive binding, just to make it complete
    my $even_amount = let rec (
        $even   = sub { $_[0] == 0 ? 1 :  $odd->($_[0] - 1) },
        $odd    = sub { $_[0] == 0 ? 0 : $even->($_[0] - 1) },
    ) {
        $even->(13);
    };

=head1 DESCRIPTION

This extension provides you with a C<let> keyword. The functionality is similar
to the construct of the same name in various Lisp dialects. For those who don't
know it, here is a side by side comparison:

    # sweet
    let ($x = 3, $y = 4) { $x + $y }

    # sour
    do { my $x = 3; my $y = 4; $x + $y }

It isn't exactly the same, but it has roughly the same effect. The complete
syntax available is

    let <binding-type>? (<assignment>, ...) { ... }

The C<binding-type> is optional. When it isn't specified, the L</Default Binding>
is used. It can also be set to C<seq> for L</Sequential Binding> and C<req> for 
L</Recursive Binding>. There are also L<Conditional Bindings|/Conditional Binding> 
that evaluate the block based on specific conditions.

Following that comes a list parenthesised list containing variables or
assignments separated by commas.  See L</Declaring Variables> for more detailed
information on what can be specified.

After the variables follows the block in which the declared variables will be
available.

The C<let> keyword acts as expression, not a statement. There won't be any
automatic statement termination after the block. The behaviour of an expression
was chosen over that of a statement so variables can be declared in a very
small scope inside expressions.

=head2 List and Scalar Context

The C<let> keyword will act as an expression and can be used inside any other
Perl expression. The last value(s) of the block will be returned as expected:

    my $z = let ($x = 3, $y = 7) { $x + $y };   # 10
    my @y = let ($x = 3, $y = 7) { $x .. $y };  # 3, 4, 5, 6, 7

If you try to call C<let> in scalar context but return multiple values, an 
error will be thrown.

=head2 Declaring Variables

Each variable specificiation is separated by a comma (C<,>). Each declaration
can be either of:

=over

=item A plain declaration

    $foo
    @foo
    %foo

This will only declare the variable but leave it undefined or empty (in case
of an array or hash).

=item An assignment

    $foo = 23
    @foo = (1..5)
    %foo = (bar => 23)

The right side of the assignment can be any expression. You can imagine a
virtual C<my> in front of every line if it helps picturing what happens.

=item Multiple Assignments

    $foo   = $bar   = 23
    $count = @ls    = (1..5)
    %map   = @pairs = (x => 2, y => 3)

You can assign a value to multiple declared variables at the same time. A
complex expression is only allowed at the right-most side. There is no
actual limit on the amount of variables you can initialise at once.

=back

Having the former in mind, the following are all valid variable specifications:

    ($x)
    (@y)
    (%z)
    ($x = 3)
    ($x = something({ qux => ($foo * $bar) }))
    ($x = 3, $y = 4)
    ($x, $y = 4)
    ($x = 3, $y)
    ($x = $y = 3)
    ($x = @y = (1 .. 5))
    (@x = (1 .. 4), %y = something())

Note that only simple variables names (e.g. C<$foo>, C<@foo> and C<%foo>) are 
allowed on the left side of the assignment or as a single declaration without
a value.

The value expression can be any valid Perl code and can access other variables
as well. What variables are available depends on the used binding. If nothing
was specified the L</Default Binding> is used and each value expression always
accesses the outer scope only. If you specified to use L</Sequential Binding>
with C<seq>, each variable declaration will have access to the variables 
declared before it. If you specified C<rec>, each declared variable is 
available for binding in each value scope.

There are also C<and> and C<anddef> which are 
L<Conditional Bindings|/Conditional Binding> that will stop as soon as they 
encounter a false or undefined variable.

=head2 Return Scope

The block containing the scoped variables is not a subroutine. Thus if you use
C<return> inside it, you will exit the scope outside of the C<let> statement:

    sub do_something {

        # returns the result from handle($result) if reached
        return let ($result = get_result()) {

            # returns from do_something
            return unless $result->is_success;

            handle($result);
        }
    }

Insofar, the C<let> statement will pretty much behave as a C<do> block would.

=head2 Default Binding

By default, all variables will be declared and initialised at the same time
(figuratively speaking). Here is an example that accesses the scope outside
of the C<let>:

    my $x = 2;
    my $y = 3;

    say let ($x = $y, $y = $x) {
        "$x, $y";
    };

The above will print C<3, 2>. Both assignments access the outer scope and the
second assignment (C<$y = $x>) assigns the value C<2> from the outer C<$x>, not
the one declared directly before it.

=head2 Sequential Binding

When you specify to use sequential binding, each value expression will have
access to the variables declared before:

    # returns 18:
    let ($x = 3, $y = $x * $x, $z = $y * 2) { $y };

This is especially useful when you need to initialise a value in multiple 
steps.

=head2 Conditional Binding

A conditional binding is basically a sequential binding, only that it will stop
and return a false value if one of its declared variables don't meet the 
specific criteria. The following conditional bindings are available:

=over

=item C<and>

    let and ($f = foo(), @ls = bar()) { map $f->($_), @ls }

The C<and> binding will return undef or an empty list if any of the variables
(C<$f> and C<@ls> above) evaluate to false in a boolean context.

=item C<anddef>

    let anddef ($f = foo(), @ls = bar()) { map $f->($_), @ls }

The C<anddef> bindings works exactly like the C<and> binding, except that it
will stop if a scalar variable is undefined, not only false.

=back

=head2 Recursive Binding

This binding method is mostly implemented for completeness sake. It will 
declare all variables up front and then initialise them. This allows each value
expression to have access to all other variables. They might not yet have been
initialised, but they can be bound in code references.

Currently, there is no safeguard against cyclic references and therefor 
leaking. This is more due to a matter of time and wil probably be resolved at
a later point.

=head1 SEE ALSO

L<syntax>

=cut
