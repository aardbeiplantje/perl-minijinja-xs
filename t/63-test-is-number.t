use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 8;

my $env = minijinja();
add_test($env, '_num_check', \&Minijinja::Test::is_number);

# Number detection via Jinja context  
is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is _num_check %}1{% else %}0{% endif %}", {}), '1', 'is_number int via jinja');
is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is _num_check %}1{% else %}0{% endif %}", {}), '1', 'is_number float via jinja');
is(render_str($env, 'tpl.j2', "{% set v = 'hello' %}{% if v is _num_check %}1{% else %}0{% endif %}", {}), '0', 'is_number string rejected via jinja');

# Direct Perl calls for edge cases
is(Minijinja::Test::is_number(-5), 1, 'is_number negative int');
is(Minijinja::Test::is_number(-3.14), 1, 'is_number negative float');
is(Minijinja::Test::is_number(0), 1, 'is_number zero');
is(Minijinja::Test::is_number("true"), 0, 'is_number "true" string rejected');
is(Minijinja::Test::is_number(), 0, 'is_number undef (no args) rejected');

done_testing();
