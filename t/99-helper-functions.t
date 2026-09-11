use strict; use warnings;
use Test::More;

use Minijinja;

# --- _can_call_test in Minijinja package (lines 1174-1176) ---
ok(Minijinja::_can_call_test('Minijinja::Test::is_string'), 
   '_can_call_test recognizes valid test function');
# Note: _can_call_test returns true for strings in existing packages 
# due to Perl's autoloading behavior with \&{$name}

# --- _compare_test direct testing (lines 1098-1107) ---
# String comparison path (line 1106) - called from Minijinja::Test package
my $result = Minijinja::Test::_compare_test('hello', 'world', sub { $_[0] eq $_[1] ? 1 : 0 });
is $result, 0, '_compare_test string comparison inequality';

$result = Minijinja::Test::_compare_test('abc', 'abc', sub { $_[0] eq $_[1] ? 1 : 0 });
is $result, 1, '_compare_test string comparison equality';

# Numeric comparison path (lines 1103-1104)
$result = Minijinja::Test::_compare_test('42', '43', sub { $_[0] < $_[1] ? 1 : 0 });
is $result, 1, '_compare_test numeric less than returns true';

$result = Minijinja::Test::_compare_test('42.5', '43.0', sub { $_[0] <= $_[1] ? 1 : 0 });
is $result, 1, '_compare_test float less or equal returns true';

# Undefined input early return (line 1100)
$result = Minijinja::Test::_compare_test(undef, 'value', sub { 0 });
is $result, 0, '_compare_test undefined first arg returns 0';

$result = Minijinja::Test::_compare_test('value', undef, sub { 0 });
is $result, 0, '_compare_test undefined second arg returns 0';

# --- _get_comparison_ops (lines 1178-1190) ---
my $ops = Minijinja::_get_comparison_ops();
isa_ok($ops, 'HASH', '_get_comparison_ops returns hashref');

ok(exists($ops->{eq}), '_get_comparison_ops has eq operator');
ok(exists($ops->{'=='}), '_get_comparison_ops has == operator');
ok(exists($ops->{ne}), '_get_comparison_ops has ne operator');
ok(exists($ops->{'!='}), '_get_comparison_ops has != operator');
ok(exists($ops->{lt}), '_get_comparison_ops has lt operator');
ok(exists($ops->{le}), '_get_comparison_ops has le operator');
ok(exists($ops->{gt}), '_get_comparison_ops has gt operator');
ok(exists($ops->{ge}), '_get_comparison_ops has ge operator');

# Test the operators work correctly
is($ops->{eq}->('hello', 'hello'), 1, 'eq operator equality true');
is($ops->{eq}->('hello', 'world'), 0, 'eq operator inequality false');

is($ops->{ne}->('hello', 'world'), 1, 'ne operator inequality true');
is($ops->{ne}->('hello', 'hello'), 0, 'ne operator equality false');

is($ops->{lt}->(3, 5), 1, 'lt operator less than true');
is($ops->{lt}->(5, 3), 0, 'lt operator not less than false');

is($ops->{le}->(5, 5), 1, 'le operator equal true');
is($ops->{le}->(3, 5), 1, 'le operator less than true');
is($ops->{le}->(7, 5), 0, 'le operator greater than false');

is($ops->{gt}->(7, 5), 1, 'gt operator greater than true');
is($ops->{gt}->(3, 5), 0, 'gt operator not greater than false');

is($ops->{ge}->(5, 5), 1, 'ge operator equal true');
is($ops->{ge}->(7, 5), 1, 'ge operator greater than true');
is($ops->{ge}->(3, 5), 0, 'ge operator less than false');

# --- _evaluate_select_pred (lines 1147-1172) ---
# With attribute - test_fn path (lines 1152-1154)
my $item = {name => 'test', value => 42};
$result = Minijinja::_evaluate_select_pred($item, 'value', 'is_integer', []);
is $result, 1, '_evaluate_select_pred with attr calls test function';

# With attribute - defined fallback (line 1156)
$item = {name => undef};
$result = Minijinja::_evaluate_select_pred($item, 'name', 'defined', []);
is $result, 0, '_evaluate_select_pred attr undefined returns 0 for defined test';

$item = {name => 'exists'};
$result = Minijinja::_evaluate_select_pred($item, 'name', 'defined', []);
is $result, 1, '_evaluate_select_pred attr defined returns 1 for defined test';

# Without attribute - test_fn path (lines 1164-1166)
$result = Minijinja::_evaluate_select_pred('hello', undef, 'is_string', []);
is $result, 1, '_evaluate_select_pred without attr calls test function';

# Without attribute - defined fallback (lines 1168-1172)
$result = Minijinja::_evaluate_select_pred(undef, undef, 'some_test', []);
is $result, 0, '_evaluate_select_pred undef item returns 0';

$result = Minijinja::_evaluate_select_pred('value', undef, 'some_test', []);
is $result, 1, '_evaluate_select_pred defined item returns 1';

done_testing();
1;
