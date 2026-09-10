use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'array_slice', \&array_slice);

is(render_str($env, 'tpl.j2', "{% for x in [0, 1, 2, 3, 4] | array_slice(1, 4) %}{{ x }},{% endfor %}", {})), '1,2,3,', '');
is(render_str($env, 'tpl.j2', "{% for x in [0, 1, 2, 3, 4] | array_slice(0, 5, 2) %}{{ x }},{% endfor %}", {})), '0,2,4,', '');

done_testing();
