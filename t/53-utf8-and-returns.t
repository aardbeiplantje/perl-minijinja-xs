use strict; use warnings;
use utf8;
use Test::More tests => 11;

use Minijinja qw(minijinja add_filter add_function render_str eval_expr);
use JSON::PP ();

binmode Test::More->builder->$_, ':encoding(UTF-8)' for qw(output failure_output todo_output);

my $env = minijinja();

# Perl character strings in and out, whatever their internal form
my $latin1 = "\x{e9}t\x{e9}";    # été without the UTF8 flag
ok(!utf8::is_utf8($latin1), 'a Latin-1 string');
is(render_str($env, 'tpl.j2', '{{ a }}', { a => $latin1 }), 'été', 'a Latin-1 string renders');
is(render_str($env, 'tpl.j2', '{{ a }}|{{ a|length }}', { a => '中文' }), '中文|2', 'CJK text, length in characters');
is(render_str($env, 'tpl.j2', '{{ h["clé"] }}', { h => { 'clé' => 'v' } }), 'v', 'non-ASCII hash keys');
is(render_str($env, 'tpl.j2', 'été {{ 1 }}', {}), 'été 1', 'non-ASCII template source');
is(eval_expr($env, "a ~ 'ß'", { a => $latin1 }), 'étéß', 'eval_expr');
ok(utf8::is_utf8(render_str($env, 'tpl.j2', '{{ a }}', { a => '中' })), 'the result is a character string');

# Callbacks get characters and may return them
add_filter($env, 'rev', sub { scalar reverse $_[0] });
is(render_str($env, 'tpl.j2', '{{ a|rev }}', { a => 'été中' }), '中été', 'a filter sees characters');

# A callback may return a blessed scalar (JSON::PP booleans)
add_function($env, 'yes', sub { JSON::PP::true() });
add_function($env, 'no', sub { JSON::PP::false() });
is(render_str($env, 'tpl.j2', '{{ yes() }} {{ no() }} {% if not no() %}ok{% endif %}', {}), 'True False ok',
   'JSON::PP booleans returned from callbacks');

# The caller's strings are not changed
my $s = "\x{e9}";
render_str($env, 'tpl.j2', '{{ s }}', { s => $s });
ok(!utf8::is_utf8($s), 'the context string is not upgraded in place');

# Array values: undef items stay undef
add_function($env, 'count_undef', sub { scalar grep { !defined } @{ $_[0] } });
is(render_str($env, 'tpl.j2', '{{ count_undef([1, none, 3]) }}', {}), '1', 'none in a list arrives as undef');

done_testing();

1;
