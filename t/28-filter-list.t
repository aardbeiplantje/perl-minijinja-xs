use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'list_fn', \&Minijinja::Filter::list_fn);

is(render_str($env, 'tpl.j2', "{% for x in [1, 2, 3] | list %}{{ x }},{% endfor %}", {}), '1,2,3,', 'list basic');
is(render_str($env, 'tpl.j2', "{% for x in [] | list %}X{% endfor %}", {}), '', 'list empty');

done_testing();

1;
