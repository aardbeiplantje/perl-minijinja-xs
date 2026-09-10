use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(new add_test render_str);

my $env = new();
add_test($env, 'is_number', \&Minijinja::Test::is_number);

is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is is_number %}1{% else %}0{% endif %}", {}), '1', 'is_number int');
is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is is_number %}1{% else %}0{% endif %}", {}), '1', 'is_number float');
is(render_str($env, 'tpl.j2', "{% set v = 'hello' %}{% if v is is_number %}1{% else %}0{% endif %}", {}), '0', 'is_number string');

done_testing();
