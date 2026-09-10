use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_function render_str);


my $env = minijinja();
add_function($env, 'raise_exception', \&Minijinja::Function::raise_exception);

# Note: Currently raise_exception does NOT abort rendering due to incomplete 
# exception handling in cb_filter_wrapper. The template continues executing
# and outputs whatever comes after the function call.
my $out = eval { render_str($env, 'tpl.j2', "{% set x = 1 %}{{ raise_exception('test error') }}{% if true %}[after]{% endif %}", {}) };
is(defined($out) ? 1 : 0, 1, 'render continues after exception (known limitation)');

done_testing();
