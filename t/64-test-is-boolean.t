use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 7;

# Note: is_boolean only works with direct Perl calls because minijinja converts boolean true/false to sv_yes/sv_no which stringify to "1"/"" indistinguishable from regular scalars.

is(Minijinja::Test::is_boolean('true'), 1, 'Minijinja::Test::is_boolean "true" exact match');
is(Minijinja::Test::is_boolean('false'), 1, 'Minijinja::Test::is_boolean "false" exact match');
is(Minijinja::Test::is_boolean('True'), 0, 'Minijinja::Test::is_boolean "True" case mismatch');
is(Minijinja::Test::is_boolean('False'), 0, 'Minijinja::Test::is_boolean "False" case mismatch');
is(Minijinja::Test::is_boolean('hello'), 0, 'Minijinja::Test::is_boolean arbitrary string rejected');
is(Minijinja::Test::is_boolean("0"), 0, 'Minijinja::Test::is_boolean "0" string rejected');
is(Minijinja::Test::is_boolean(), 0, 'Minijinja::Test::is_boolean undef (no args) rejected');

done_testing();
