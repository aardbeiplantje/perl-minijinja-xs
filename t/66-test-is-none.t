use Minijinja qw(minijinja add_test render_str);
use strict; use warnings;
use Test::More tests => 7;

my $env = minijinja();
add_test($env, 'is_none', \&Minijinja::Test::is_none);

# None detection via Jinja context
is(render_str($env, 'tpl.j2', "{% set v = None %}{% if v is is_none %}1{% else %}0{% endif %}", {}), '1', 'is_none None literal');

# Undefined values
is(render_str($env, 'tpl.j2', "{% if nonexistent_var is is_none %}1{% else %}0{% endif %}", {}), '1', 'is_none undefined var');

# Direct Perl calls for edge cases  
is(Minijinja::Test::is_none(), 1, 'is_none undef (no args) is none');
is(Minijinja::Test::is_none(''), 0, 'is_none empty string is NOT none');
is(Minijinja::Test::is_none(undef), 1, 'is_none explicit undef is none');
is(Minijinja::Test::is_none("None"), 0, 'is_none string "None" is NOT none');
is(Minijinja::Test::is_none(0), 0, 'is_none integer zero is NOT none');

done_testing();

1;
