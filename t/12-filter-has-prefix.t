use strict; use warnings;
use Test::More tests => 5;

use Minijinja qw(
    new add_function render_str func_startswith startswith
);

my $env = new();  
add_function($env, 'startswith', \&func_startswith);

is(render_str($env, 'tpl.j2', "{{ startswith('hello world', 'hel') }}", {}), 
   '1', 'startswith true match');

is(render_str($env, 'tpl.j2', "{{ startswith('hello world', 'xyz') }}", {}), 
   '0', 'startswith false no match');

done_testing();
