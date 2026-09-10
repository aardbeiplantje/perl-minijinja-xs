use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'values', \&Minijinja::Filter::values);

is(render_str($env, 'tpl.j2', "{% for v in {'b':2,'a':1,'c':3} | values %}{{ v }},{% endfor %}", {}), '1,2,3,', 'values filter');

done_testing();
