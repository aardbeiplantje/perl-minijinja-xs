use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_string', \&Minijinja::Test::is_string);

is(render_str($env, 'tpl.j2', "{% set v = 'hello' %}{% if v is is_string %}1{% else %}0{% endif %}", {}), '1', 'is_string string');
is(render_str($env, 'tpl.j2', "{% set arr = [1,2] %}{% set v = arr %}{% if v is is_string %}1{% else %}0{% endif %}", {}), '0', 'is_string array');

done_testing();
