use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter render_str
    filter_first
);


my $env = new();
add_filter($env, 'first', \&filter_first);

is(render_str($env, 'tpl.j2', "{{ [1, 2, 3] | first }}", {}), '1', 'first basic');
is(render_str($env, 'tpl.j2', "{% set arr = [] %}{% if arr | length == 0 %}{{ '' }}{% else %}{{ arr | first }}{% endif %}", {}), '', 'first empty array');

done_testing();
