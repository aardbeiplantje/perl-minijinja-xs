use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'dictsort', \&Minijinja::Filter::dictsort);

is(render_str($env, 'tpl.j2', "{% for k,v in {'b':2,'a':1} | dictsort %}[{{k}}={{v}}]{% endfor %}", {}), '[a=1][b=2]', 'dictsort');

done_testing();
