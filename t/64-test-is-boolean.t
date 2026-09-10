use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(new add_test render_str);

# Note: Minijinja::Test::is_boolean works with direct Perl calls (not through Jinja context)
# because minijinja converts boolean true/false to PL_sv_yes/PL_sv_no 
# which stringify to "1"/"" - indistinguishable from regular scalars

is(Minijinja::Test::is_boolean("true"), 1, 'Minijinja::Test::is_boolean "true"');
is(Minijinja::Test::is_boolean("false"), 1, 'Minijinja::Test::is_boolean "false"');
is(Minijinja::Test::is_boolean("hello"), 0, 'Minijinja::Test::is_boolean non-boolean string');

done_testing();
