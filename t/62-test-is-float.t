use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 8;

# Float detection via Jinja context  
my $env = minijinja();
add_test($env, '_float_check', \&Minijinja::Test::is_float);
is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is _float_check %}1{% else %}0{% endif %}", {}), '1', 'is_float positive float via jinja');
is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is _float_check %}1{% else %}0{% endif %}", {}), '0', 'is_float int rejected via jinja');

# Direct Perl calls for edge cases
is(Minijinja::Test::is_float(-3.14), 1, 'is_float negative float');
is(Minijinja::Test::is_float(0.5), 1, 'is_float decimal between 0 and 1');
is(Minijinja::Test::is_float(42), 0, 'is_float pure integer rejected');
is(Minijinja::Test::is_float("3.0"), 0, 'is_float "X.0" excluded (looks like int)');
is(Minijinja::Test::is_float('hello'), 0, 'is_float non-numeric string rejected');
is(Minijinja::Test::is_float(), 0, 'is_float undef (no args) rejected');

done_testing();
