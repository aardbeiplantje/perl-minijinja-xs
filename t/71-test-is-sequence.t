use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(minijinja add_test render_str);

my $env = minijinja();
add_test($env, 'is_sequence', \&Minijinja::Test::is_sequence);

# Sequence: only arrays qualify as sequences (hashrefs and scalars do not)
is(render_str($env, 'tpl.j2', "{% set x = [1,2,3] %}{% if x is is_sequence %}1{% else %}0{% endif %}", {}), '1', 'array IS a sequence');
is(render_str($env, 'tpl.j2', "{% set x = 'hello' %}{% if x is is_sequence %}1{% else %}0{% endif %}", {}), '0', 'string is NOT a sequence');
is(render_str($env, 'tpl.j2', "{% set x = {'a': 1} %}{% if x is is_sequence %}1{% else %}0{% endif %}", {}), '0', 'hash is NOT a sequence');
is(render_str($env, 'tpl.j2', "{% set x = 42.5 %}{% if x is is_sequence %}1{% else %}0{% endif %}", {}), '0', 'float is NOT a sequence');
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_sequence %}1{% else %}0{% endif %}", {}), '0', 'undefined value is NOT a sequence');

done_testing();

1;
