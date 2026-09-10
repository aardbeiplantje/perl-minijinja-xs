use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'split', \&Minijinja::Filter::split);

is(render_str($env, 'tpl.j2', "{% for p in 'a b c' | split %}{{ p }},{% endfor %}", {}), 'a,b,c,', 'split space default');
is(render_str($env, 'tpl.j2', "{% for p in 'x,y,z' | split(',') %}{{ p }},{% endfor %}", {}), 'x,y,z,', 'split custom delimiter');

done_testing();
