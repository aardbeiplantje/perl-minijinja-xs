use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(
    new add_test render_str
    is_boolean
);

# Note: is_boolean works with direct Perl calls (not through Jinja context)
# because minijinja converts boolean true/false to PL_sv_yes/PL_sv_no 
# which stringify to "1"/"" - indistinguishable from regular scalars

is(is_boolean("true"), 1, 'is_boolean "true"');
is(is_boolean("false"), 1, 'is_boolean "false"');
is(is_boolean("hello"), 0, 'is_boolean non-boolean string');

done_testing();
