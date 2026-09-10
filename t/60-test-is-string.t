use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(
    new add_test render_str
    is_string
);

my $env = new();
add_test($env, 'is_string', \&is_string);

is(render_str($env, 'tpl.j2', "{% set v = 'hello' %}{% if v is is_string %}1{% else %}0{% endif %}", {}), '1', 'is_string string');
is(render_str($env, 'tpl.j2', "{% set arr = [1,2] %}{% set v = arr %}{% if v is is_string %}1{% else %}0{% endif %}", {}), '0', 'is_string array');

done_testing();
