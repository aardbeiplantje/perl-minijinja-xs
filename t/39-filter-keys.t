use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(minijinja add_filter render_str);


my $env = minijinja();
add_filter($env, 'keys', \&Minijinja::Filter::keys_fn);

is(render_str($env, 'tpl.j2', "{% for k in {'b':2,'a':1,'c':3} | keys %}{{ k }},{% endfor %}", {}), 'a,b,c,', 'keys sorted');

done_testing();

1;
