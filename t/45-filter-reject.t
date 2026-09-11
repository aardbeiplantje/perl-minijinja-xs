use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'reject', \&Minijinja::Filter::reject);

is(render_str($env, 'tpl.j2', "{% set arr = [0, 1, '', 'yes'] %}{% for x in arr | reject %}{{x}}Z{% endfor %}", {}), 'Z', 'reject filter');

done_testing();

1;
