use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_filter render_str
    last
);


my $env = new();
add_filter($env, 'last', \&last);

is(render_str($env, 'tpl.j2', "{% set x = [1, 2, 3] | last %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), '3', 'last basic');
is(render_str($env, 'tpl.j2', "{% set x = [] | last %}{% if x is defined %}{{ x }}{% endif %}{% else %}undef{% endif %}", {}), 'undef', 'last empty');

done_testing();
