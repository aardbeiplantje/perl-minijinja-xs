use strict; use warnings;
use Test::More tests => 2;

use Minijinja qw(add_test render_str);

# Note: is_none works correctly with direct Perl calls (undef returns 1)
# and with Jinja context for actual None values

my $env = Minijinja::minijinja();
add_test($env, 'is_none', \&Minijinja::Test::is_none);

is(render_str($env, 'tpl.j2', "{% set v = None %}{% if v is is_none %}1{% else %}0{% endif %}", {}), '1', 'is_none None literal');
is(Minijinja::Test::is_none(undef), 1, 'is_none undef value');

done_testing();
