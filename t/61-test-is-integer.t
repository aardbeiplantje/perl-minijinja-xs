use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 8;

# Integer detection via Jinja context  
my $env = minijinja();
add_test($env, '_int_check', \&Minijinja::Test::is_integer);
is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is _int_check %}1{% else %}0{% endif %}", {}), '1', 'is_integer positive int via jinja');
is(render_str($env, 'tpl.j2', "{% set v = 3.14 %}{% if v is _int_check %}1{% else %}0{% endif %}", {}), '0', 'is_integer float rejected via jinja');

# Direct Perl calls for edge cases
is(Minijinja::Test::is_integer(0), 1, 'is_integer zero');
is(Minijinja::Test::is_integer(-5), 1, 'is_integer negative int');
is(Minijinja::Test::is_integer(999999), 1, 'is_integer large int');
is(Minijinja::Test::is_integer(''), 0, 'is_integer empty string rejected');
is(Minijinja::Test::is_integer("0"), 1, 'is_integer "0" matches integer regex');
is(Minijinja::Test::is_integer('3.14'), 0, 'is_integer decimal string rejected');

done_testing();
