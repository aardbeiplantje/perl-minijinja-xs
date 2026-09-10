use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_test render_str);

# Note: Minijinja::Test::is_callable works with direct Perl calls (not through Jinja context)
# because minijinja cannot preserve CODE references through its value system
# - code refs passed via {% set v = sub{1} %} become undefined in minijinja

is(Minijinja::Test::is_callable(sub { 1 }), 1, 'Minijinja::Test::is_callable code ref');
is(Minijinja::Test::is_callable("hello"), 0, 'Minijinja::Test::is_callable string');

done_testing();
