use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter render_str
    filter_split
);


my $env = new();
add_filter($env, 'split', \&filter_split);

is(render_str($env, 'tpl.j2', "{% for p in 'a b c' | split %}{{ p }},{% endfor %}", {}), 'a,b,c,', 'split space default');
is(render_str($env, 'tpl.j2', "{% for p in 'x,y,z' | split(',') %}{{ p }},{% endfor %}", {}), 'x,y,z,', 'split custom delimiter');

done_testing();
