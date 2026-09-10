use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'reject', \&Minijinja::Filter::reject);

is(render_str($env, 'tpl.j2', "{% for x in [0, 1, '', 'yes', None] | reject %}{{ x }},{% endfor %}", {}), '0,,,', 'reject filter');

done_testing();
