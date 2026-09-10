use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(new add_test render_str);

my $env = new();
add_test($env, 'is_integer', \&Minijinja::Test::is_integer);

is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is is_integer %}1{% else %}0{% endif %}", {}), '1', 'is_integer int');
is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is is_integer %}1{% else %}0{% endif %}", {}), '0', 'is_integer float');

done_testing();
