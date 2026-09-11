use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'select_fn', \&Minijinja::Filter::select_fn);

is(render_str($env, 'tpl.j2', "{% for x in [0, 1, '', 'yes', None] | select %}{{ x }},{% endfor %}", {}), '1,yes,', 'select filter');

done_testing();

1;
