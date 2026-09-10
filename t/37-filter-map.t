use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'map', \&Minijinja::Filter::map_fn);

is(render_str($env, 'tpl.j2', "{% for n in [{'name':'alice'},{'name':'bob'}] | map('name') %}{{ n }},{% endfor %}", {}), 'alice,bob,', 'map extract field');

done_testing();
