use strict; use warnings;
use Test::More;

use Minijinja qw(minijinja);

# is_divisibleby - undefined/divisor=0 (lines 1005-1006)  
ok(!Minijinja::Test::is_divisibleby(undef, 3), 'is_divisibleby undef value returns false');
ok(!Minijinja::Test::is_divisibleby(10, undef), 'is_divisibleby undef divisor returns false');
ok(!Minijinja::Test::is_divisibleby(10, 0), 'is_divisibleby zero divisor returns false');
ok(Minijinja::Test::is_divisibleby(10, 5), 'is_divisibleby divisible returns true');
ok(!Minijinja::Test::is_divisibleby(10, 3), 'is_divisibleby not divisible returns false');

# is_in - all data structure types (lines 1015-1027)
my $arr = [1, 2, 3];
ok(Minijinja::Test::is_in(2, $arr), 'is_in arrayref finds value');
ok(!Minijinja::Test::is_in(5, $arr), 'is_in arrayref missing value returns false');

my $hash = {a => 1, b => 2, c => 3};
ok(Minijinja::Test::is_in('b', $hash), 'is_in hashref finds key');
ok(!Minijinja::Test::is_in('z', $hash), 'is_in hashref missing key returns false');

ok(Minijinja::Test::is_in('world', 'hello world foo'), 'is_in string finds substring');
ok(!Minijinja::Test::is_in('missing', 'hello world'), 'is_in string missing returns false');

done_testing();
1;
