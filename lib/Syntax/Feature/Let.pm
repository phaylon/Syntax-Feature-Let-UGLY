use strict;
use warnings;

# ABSTRACT: Scoped declaration of lexical variables

package Syntax::Feature::Let;
use parent 'Devel::Declare::Handler::PPI';

use Carp                               'confess';
use Devel::Declare::Handler::PPI::Util ':all';

use aliased 'PPI::Token::Word';
use aliased 'PPI::Token::Symbol';
use aliased 'PPI::Structure::List';
use aliased 'PPI::Structure::Block';
use aliased 'PPI::Statement::Compound';

use namespace::clean;

$Carp::Internal{+__PACKAGE__}++;

sub make_keyword_name {
    my ($class, %args) = @_;

    # allow users to override keyword, but default to 'let'
    return $args{options}{ -as } || 'let';
}

sub transform {
    my ($class, $ppi, $args, $shadow) = @_;

    # get identity and variable specification
    my $ident               = $class->make_keyword_name(%$args);
    my ($var_spec, $rest)   = first_significant $ppi;

    # if the declarator is followed by a bareword, it is treated as a scoping identifier
    my $type = 'default';
    if ($var_spec and $var_spec->isa(Word)) {

        # store type and fetch real variable specification
        $type = $var_spec->content;
        ($var_spec, $rest) = first_significant $rest;
    }

    confess qq(Expected variable specification after '$ident' keyword)
        unless $var_spec and $var_spec->isa(List);

    # extract block and following content
    my ($var_comp, $not_me) = first_significant $rest;

    do {    
        no warnings 'uninitialized';    
        confess qq(Expected a code block after '$ident' keyword variable specification, found '$var_comp')

    } unless $var_comp and $var_comp->isa(Block);

    # parse variable signature into a tree
    my $variables = $class->_deparse_var_spec($var_spec);

    # build new code with var declarations and scoped block
    my $new_code = sprintf q((do { no warnings q(syntax); %s; do %s })%s),
        $class->_render_var_spec($type, $variables),
        $var_comp,
        $not_me;

    return $new_code;
}

sub _render_var_spec {
    my ($class, $type, $variables) = @_;

    # delegation method
    my $handler = "_render_${type}_declaration";

    confess qq(Unknown variable declaration binding identifier '$type')
        unless $class->can($handler);

    return $class->$handler($variables);
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

sub _deparse_var_spec {
    my ($class, $var_spec) = @_;

    # no variables. makes no sense, but who cares?
    return () unless $var_spec->schildren;

    # separate variable declaration expression by comma
    my $expr         = $var_spec->schild(0);
    my @declarations = split_by_operator ',', $expr->children;

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

1;

__END__

=method make_keyword_name

    $kw_str = $class->make_keyword_name( %args );

This method is used to decide on the name of the keyword. Defaults to C<let>
unless overriden at import time via:

    use syntax let => { -as => 'scope' };

=method transform

Called by L<syntax> to transform the declarative statement into valid Perl code.

=option -as

Accepts a string that will be used as the name for the installed keyword 
declarator.

=head1 SYNOPSIS

    # using the syntax import dispatch mechanism
    use strict;
    use syntax 'let';

    # most simple
    my $sum = let ($x = 3, $y = 4) {

        # returns 7
        $x + $y;
    };

    # undefined values
    let ($x) { 
        
        # prints 'no'
        print defined($x) ? "yes\n" : "no\n";
    };

    # also works with arrays as expected
    let (@x = (1 .. 3), @y = (4 .. 5)) { 
        
        # prints X(1 2 3) Y(4 5 6)
        print "X(@x) Y(@y)\n";
    };

    # can also assign to multiple vars
    let ($count = @items = (1 .. 5)) {

        # Got 5 items: 1 2 3 4 5
        print "Got $count items: @items\n";
    };

    # normal scoping only binds new vars in body
    my $foo = 23;
    let ($foo = 1000. $bar = $foo) {

        # prints 1000/23
        print "$foo/$bar\n";
    };

    # sequential scoping allows access to previews variables
    let seq ($num = 7, $mult = $num * 3) {

        # 21
        print "$num\n";
    };

    # recursive scoping makes binding each available to each other
    my @items = (1 .. 10);
    let rec (
        $mark = sub {
            my ($mark, $next) = @_;

            return sub {
                return unless @_;
                my $curr = shift;
                return [$mark => $curr], $next->(@_);
            };
        },
        $mark_as_even = sub { $mark->(even => $mark_as_odd)->(@_) },
        $mark_as_odd  = sub { $mark->(odd  => $mark_as_even)->(@_) },
    ) {

        $mark_as_odd->(@items);
    };

=head1 DESCRIPTION

This module extends Perl's syntax with a C<let> keyword (unless another 
keyword is chosen). This will allow you to declare lexical variables like
with C<my> but make them only available to a specific scope.

It is basically a nicer syntax to do stuff like

    do {
        my $x = 3;
        my $y = 4;
        $x * $y;
    };

but write it like this

    let ($x = 3, $y = 4) { $x * $y }

=head2 General Syntax

    let <binding-type>? (<variable-specification>) {<code-block>}

=over

=item * C<binding-type>

    (optional) seq | rec

This optional bareword element will define the declarative scoping rules. See 
L</Default Binding>, L</Sequential Binding> and L</Recirsive Binding> for more
information.

=item * C<variable-specification>

    (<variable-declaration>, ...)

The different variable declarations are enclosed in parenthesis and separated by
simple commas. Example:

    ($x = 3, $y = 4, $z)

=item * C<variable-declaration>

    <variable>
    <variable> = <value>
    <variable> = <variable> = <value>
    ...

Each declaration has zero or more C<value> expressions. If there is no assignment,
the value will default to undef (or an empty list, etc.). If there is an assignment,
the last part is expected to be the value expression, while all previous elements
must be lexically declarable variable names.

=item * C<code-block>

The scoped block of code that has access to all variables that were declared.

=back

=head2 Multiple values

You are not bound to a single assignment per declaration. There are many possibilities:

    # $x is undefined
    let ($x) { ... }

    # $x contains 23
    let ($x = 23) { ... }

    # $x and $y contain 23
    let ($x = $y = 23) { ... }

    # $x contains 3, @y contains (1, 2, 3)
    let ($x = @y = (1 .. 3)) { ... }

Note however that these things cannot be nested:

    # WON'T WORK
    let ($x = ($y = 23)) { ... }

The above won't detect C<$y> as one of the variables to declare.

=head2 Default Binding

    let (...) { ... }

With the most common usage only the code block will have access to the
declared variables. The value expressions in the variable specification will
be bound to the outer scope, and this none of the new variables will be
available in there.

As an example, the following code will declare two new variables that have
swapped values from the outer scope:

    my $foo = 23;
    my $bar = 42;

    let ($foo = $bar, $bar = $foo) {

        # prints: 42, 23
        print "$foo, $bar\n";
    };

This is in essence the same as doing:

    my $foo = 23;
    my $bar = 42;

    do {
        my $foo = $bar and my $bar = $foo;

        print "$foo, $bar\n";
    };

=head2 Sequential Binding

    let seq (...) { ... }

Sometimes you don't want to exclusively bind to the outer variables. Sequential
scoping will make each declared variable directly usable by the next one:

    # this returns 46
    let seq ($x = 23, $y = $x * 2) { $x }

In pure Perl, this would look like this:

    do {
        my $x = 23;
        my $y = $x * 2;

        $x;
    };

=head2 Recursive Binding

    let rec (...) { ... }

This is a rather special case of binding. It will first declare all variables, and
then, after all variables have been created, assign their values. This allows the
value expressions to contain functions that bind to any other newly created variable.

The following example is not very useful, but it is a good small demonstration of
the feature:

    let rec (
        $is_even = sub { $_[0] == 0 ? 1 : $is_odd->($_[0] - 1) },
        $is_odd  = sub { $_[0] == 0 ? 0 : $is_even->($_[0] - 1) },
    ) {

        # prints 1
        print $is_odd->(13), "\n";
    };

Without the additional syntax we'd have to write this:

    do {
        my ($is_even, $is_odd);
        $is_even = sub { $_[0] == 0 ? 1 : $is_odd->($_[0] - 1) };
        $is_odd  = sub { $_[0] == 0 ? 1 : $is_even->($_[0] - 1) };

        print $is_odd->(13), "\n";
    };

=head1 SEE ALSO

L<syntax>

=cut
