use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_test render_str);

my $env = new();
add_test($env, 'is_float', \&Minijinja::Test::is_float);

is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is is_float %}1{% else %}0{% endif %}", {}), '1', 'is_float float');
is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is is_float %}1{% else %}0{% endif %}", {}), '0', 'is_float int');

done_testing();
