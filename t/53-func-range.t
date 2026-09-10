use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter add_function render_str);


my $env = minijinja();
add_function($env, 'range', \&Minijinja::Function::range);

is(render_str($env, 'tpl.j2', "{% for x in range(10) %}{{ x }},{% endfor %}", {}), '0,1,2,3,4,5,6,7,8,9,', 'range basic');
is(render_str($env, 'tpl.j2', "{% for x in range(2, 6) %}{{ x }},{% endfor %}", {}), '2,3,4,5,', 'range with start stop');

done_testing();
