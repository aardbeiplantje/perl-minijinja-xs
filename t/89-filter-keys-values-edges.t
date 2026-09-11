use strict; use warnings;
use Test::More;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'keys_fn', \&Minijinja::Filter::keys_fn);
add_filter($env, 'values', \&Minijinja::Filter::values);

# keys_fn with undefined/non-hash input (line 513)
is(render_str($env, 'tpl.j2', "{% for k in undefined | keys_fn %}X{% endfor %}", {}), '', 'undefined to keys returns empty');
is(render_str($env, 'tpl.j2', "{% for k in [1,2] | keys_fn %}X{% endfor %}", {}), '', 'array to keys returns empty');

# values with undefined/non-hash input (line 520)
is(render_str($env, 'tpl.j2', "{% for v in undefined | values %}X{% endfor %}", {}), '', 'undefined to values returns empty');
is(render_str($env, 'tpl.j2', "{% for v in [1,2] | values %}X{% endfor %}", {}), '', 'array to values returns empty');

done_testing();
1;
