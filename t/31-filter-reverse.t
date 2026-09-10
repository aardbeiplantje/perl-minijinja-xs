use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str reverse_fn);


my $env = new();
add_filter($env, 'reverse_fn', \&reverse_fn);

is(render_str($env, 'tpl.j2', "{% for x in [1, 2, 3] | reverse %}{{ x }},{% endfor %}", {})), '3,2,1,', '');
is(render_str($env, 'tpl.j2', "{% for x in [] | reverse %}X{% endfor %}", {})), '', '');

done_testing();
