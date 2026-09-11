use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 7;

# Note: is_callable only works with direct Perl calls because minijinja cannot
# preserve CODE references through its value system.

# Callable types via direct Perl call  
is(Minijinja::Test::is_callable(sub { 1 }), 1, 'Minijinja::Test::is_callable code ref');
is(Minijinja::Test::is_callable(\&minijinja), 1, 'Minijinja::Test::is_callable named sub ref');

# Non-callable types — tested via both Jinja context and direct Perl calls
my $env = minijinja();
add_test($env, '_callable_check', \&Minijinja::Test::is_callable);
is(render_str($env, 'tpl.j2', "{% set v = 'hello' %}{% if v is _callable_check %}1{% else %}0{% endif %}", {}), '0', 'is_callable string rejected');
is(render_str($env, 'tpl.j2', "{% set v = 42 %}{% if v is _callable_check %}1{% else %}0{% endif %}", {}), '0', 'is_callable int rejected');
is(render_str($env, 'tpl.j2', "{% set v = [1,2] %}{% if v is _callable_check %}1{% else %}0{% endif %}", {}), '0', 'is_callable arrayref rejected');
is(render_str($env, 'tpl.j2', "{% set v = {'a': 1} %}{% if v is _callable_check %}1{% else %}0{% endif %}", {}), '0', 'is_callable hashref rejected');
is(Minijinja::Test::is_callable(), 0, 'Minijinja::Test::is_callable undef (no args) rejected');

done_testing();

1;
