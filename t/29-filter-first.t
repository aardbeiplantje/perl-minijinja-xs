use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'first', \&Minijinja::Filter::first);

is(render_str($env, 'tpl.j2', "{{ [1, 2, 3] | first }}", {}), '1', 'first basic');
is(render_str($env, 'tpl.j2', "{% set arr = [] %}{% if arr | length == 0 %}{{ '' }}{% else %}{{ arr | first }}{% endif %}", {}), '', 'first empty array');

done_testing();
