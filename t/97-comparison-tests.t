use strict; use warnings;
use Test::More;

use Minijinja;

# Comparison tests called directly (lines 1032-1068)

# String equality via is_eq/is_equalto
is(Minijinja::Test::is_eq('hello', 'hello'), 1, 'is_eq string equality true');
is(Minijinja::Test::is_eq('hello', 'world'), 0, 'is_eq string inequality false');
is(Minijinja::Test::is_equalto('hello', 'hello'), 1, 'is_equalto string equality true');
is(Minijinja::Test::is_equalto('hello', 'world'), 0, 'is_equalto string inequality false');

# Numeric comparisons via _compare_test numeric path
is(Minijinja::Test::is_lt(3, 5), 1, 'is_lt numeric less than true');
is(Minijinja::Test::is_lt(5, 3), 0, 'is_lt not less than false');
is(Minijinja::Test::is_lt(3.14, 5), 1, 'is_lt float less than true');

is(Minijinja::Test::is_le(5, 5), 1, 'is_le equal values true');
is(Minijinja::Test::is_le(3, 5), 1, 'is_le less than true');
is(Minijinja::Test::is_le(7, 5), 0, 'is_le greater than false');

is(Minijinja::Test::is_gt(7, 5), 1, 'is_gt greater than true');
is(Minijinja::Test::is_gt(3, 5), 0, 'is_gt not greater than false');

is(Minijinja::Test::is_ge(5, 5), 1, 'is_ge equal values true');
is(Minijinja::Test::is_ge(7, 5), 1, 'is_ge greater than true');
is(Minijinja::Test::is_ge(3, 5), 0, 'is_ge less than false');

# Not equal
is(Minijinja::Test::is_ne('hello', 'world'), 1, 'is_ne string inequality true');
is(Minijinja::Test::is_ne('hello', 'hello'), 0, 'is_ne string equality false');
is(Minijinja::Test::is_ne(5, 3), 1, 'is_ne numeric inequality true');

done_testing();
1;
