use strict; use warnings;
use Test::More tests => 4;

use Minijinja qw(minijinja add_filter render_str);

my $env = minijinja();
add_filter($env, 'items', \&Minijinja::Filter::items);

# Hash input - returns sorted [key, value] pairs  
is(render_str($env, 'tpl.j2', "{% for item in data | items %}[{{ item.0 }}={{ item.1 }}]{% endfor %}", { data => { b => 2, a => 1, c => 3 } }),
   '[a=1][b=2][c=3]', 'items on hash returns sorted pairs');

# Empty hash
is(render_str($env, 'tpl.j2', "{% for x in {} | items %}X{% endfor %}", {}), '', 'empty hash items yields nothing');

# Array input (should return empty arrayref)  
is(render_str($env, 'tpl.j2', "{% for x in arr | items %}X{% endfor %}", { arr => [1,2,3] }), '', 'array to items yields nothing');

# Scalar input (should return empty arrayref)  
is(render_str($env, 'tpl.j2', "{% for x in str_val | items %}X{% endfor %}", { str_val => "hello" }), '', 'scalar to items yields nothing');
