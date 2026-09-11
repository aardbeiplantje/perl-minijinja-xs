use strict; use warnings;
use Test::More;

use Minijinja qw(minijinja add_function render_str);

my $env = minijinja();
add_function($env, 'range', \&Minijinja::Function::range);

# Only $start provided (lines 826-828) - creates range(0..start)
is(render_str($env, 'tpl.j2', "{% for x in range(5) %}{{x}},{% endfor %}", {}), '0,1,2,3,4,', 'range with single arg');

# Step < 0 case (lines 842-843)  
is(render_str($env, 'tpl.j2', "{% for x in range(5, 0, -1) %}{{x}},{% endfor %}", {}), '5,4,3,2,1,', 'range negative step descending');

# Undefined parameter checks (line 836)
is(render_str($env, 'tpl.j2', "{% for x in range(None) %}{{x}},{% endfor %}", {}), '', 'undefined start returns empty');

done_testing();
1;
