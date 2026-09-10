use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_filter render_str);


my $env = new();
add_filter($env, 'min', \&Minijinja::Filter::min);

is(render_str($env, 'tpl.j2', "{% set x = [3, 1, 2] | min %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), '1', 'min basic');
is(render_str($env, 'tpl.j2', "{% set x = [] | min %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), 'undef', 'min empty');

done_testing();
