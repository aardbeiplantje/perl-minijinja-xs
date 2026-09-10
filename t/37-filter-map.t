use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(
    new add_filter render_str
    map_fn
);


my $env = new();
add_filter($env, 'map_fn', \&map_fn);

is(render_str($env, 'tpl.j2', "{% for n in [{'name':'alice'},{'name':'bob'}] | map('name') %}{{ n }},{% endfor %}", {}), 'alice,bob,', 'map extract field');

done_testing();
