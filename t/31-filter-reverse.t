use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'reverse', \&Minijinja::Filter::reverse_fn);

is(render_str($env, 'tpl.j2', "{% for x in [1, 2, 3] | reverse %}{{ x }},{% endfor %}", {}), '3,2,1,', 'reverse basic');
is(render_str($env, 'tpl.j2', "{% for x in [] | reverse %}X{% endfor %}", {}), '', 'reverse empty');

done_testing();
