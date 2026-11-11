use strict; use warnings;
use Test::More tests => 3;

use Minijinja qw(minijinja render_str);

# {% break %} / {% continue %}: minijinja's loop_controls feature, which scripts/setup-minijinja.sh builds the
# library with (chat templates use them)
my $env = minijinja();

is(render_str($env, 'tpl.j2', "{% for x in [1, 2, 3, 4] %}{% if x == 3 %}{% break %}{% endif %}{{ x }},{% endfor %}", {}),
   '1,2,', 'break');
is(render_str($env, 'tpl.j2', "{% for x in [1, 2, 3, 4] %}{% if x == 3 %}{% continue %}{% endif %}{{ x }},{% endfor %}", {}),
   '1,2,4,', 'continue');
is(render_str($env, 'tpl.j2', "{% for m in ms | reverse %}{% if m.role == 'user' %}{{ m.content }}{% break %}{% endif %}{% endfor %}",
              { ms => [{ role => 'user', content => 'a' }, { role => 'user', content => 'b' }, { role => 'assistant', content => 'c' }] }),
   'b', 'break in a search from the end');
