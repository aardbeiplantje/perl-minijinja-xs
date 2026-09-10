use strict; use warnings;
use Test::More tests => 1;

use Minijinja qw(new add_filter render_str keys_fn);


my $env = new();
add_filter($env, 'keys_fn', \&Minijinja::Filter::keys_fn);

is(render_str($env, 'tpl.j2', "{% for k in {'b':2,'a':1,'c':3} | keys %}{{ k }},{% endfor %}", {}), 'a,b,c,', 'keys sorted');

done_testing();
