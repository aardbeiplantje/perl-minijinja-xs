use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'rsplit', \&Minijinja::Filter::rsplit);

is(render_str($env, 'tpl.j2', "{% for p in 'x,y,z' | rsplit(',') %}{{ p }},{% endfor %}", {}), 'x,y,z,');
is(render_str($env, 'tpl.j2', "{% for p in 'a,b,c,d,e' | rsplit(',', 2) %}{{ p }},{% endfor %}", {}), 'a,b,c,d,e,');

done_testing();
