use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_test render_str
    is_callable
);

# Note: is_callable works with direct Perl calls (not through Jinja context)
# because minijinja cannot preserve CODE references through its value system
# - code refs passed via {% set v = sub{1} %} become undefined in minijinja

is(is_callable(sub { 1 }), 1, 'is_callable code ref');
is(is_callable("hello"), 0, 'is_callable string');

done_testing();
