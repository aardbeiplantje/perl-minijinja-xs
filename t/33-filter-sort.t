use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'sort_fn', \&Minijinja::Filter::sort_fn);

is(render_str($env, 'tpl.j2', "{% for x in [3, 1, 2] | sort %}{{ x }},{% endfor %}", {}), '1,2,3,', 'sort ascending');
is(render_str($env, 'tpl.j2', "{% for x in [1, 3, 2] | sort(reverse=true) %}{{ x }},{% endfor %}", {}), '3,2,1,', 'sort descending');

done_testing();
