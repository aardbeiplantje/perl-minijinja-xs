use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(
    new add_filter render_str
    select_fn
);


my $env = new();
add_filter($env, 'select_fn', \&select_fn);

is(render_str($env, 'tpl.j2', "{% for x in [0, 1, '', 'yes', None] | select %}{{ x }},{% endfor %}", {}), '1,yes,', 'select filter');

done_testing();
