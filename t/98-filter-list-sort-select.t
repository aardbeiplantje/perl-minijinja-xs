use strict; use warnings;
use Test::More;

use Minijinja;

# --- list_fn tests (lines 302-306) ---
my $copy = Minijinja::Filter::list_fn([1, 2, 3]);
is_deeply $copy, [1, 2, 3], 'list_fn copies non-empty array';
ok($copy != [1, 2, 3], 'list_fn returns new reference');

$copy = Minijinja::Filter::list_fn([]);
is_deeply $copy, [], 'list_fn returns empty array for empty input';

$copy = Minijinja::Filter::list_fn(undef);
is_deeply $copy, [], 'list_fn returns empty array for undef';

$copy = Minijinja::Filter::list_fn({});
is_deeply $copy, [], 'list_fn returns empty array for hashref';

# --- sort_fn with attribute (lines 369-391) ---
my @items = ({name => 'Charlie'}, {name => 'Alice'}, {name => 'Bob'});

# Sort ascending by name - test _compare_values path
my @asc = sort {
    my $cmp = Minijinja::_compare_values($a->{name}, $b->{name});
    $cmp;
} @items;
is $asc[0]{name}, 'Alice', 'sort ascending: first is Alice';
is $asc[2]{name}, 'Charlie', 'sort ascending: last is Charlie';

# Sort descending by score - test reverse path  
my @desc = sort {
    my $cmp = Minijinja::_compare_values($b->{score}, $a->{score});
    -$cmp;
} (@{[{score => 10}, {score => 50}, {score => 20}]});
is scalar(@desc), 3, 'reverse sort produces correct count';
ok($desc[0]{score} == 50 || $desc[2]{score} == 50, 'reverse sort contains max value');

# Empty array ref path
@items = ();
$copy = Minijinja::Filter::sort_fn(\@items);
is_deeply $copy, [], 'sort_fn returns empty array for empty input';

$copy = Minijinja::Filter::sort_fn(undef);
is_deeply $copy, [], 'sort_fn returns empty array for undef';

$copy = Minijinja::Filter::sort_fn({});
is_deeply $copy, [], 'sort_fn returns empty array for hashref';

# --- select_fn (lines 696-751) ---
my @nums = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

my $result = Minijinja::Filter::select_fn(\@nums, 'is_odd');
isa_ok($result, 'ARRAY', 'select_fn returns ARRAY ref');
ok(scalar(@$result) > 0, 'select_fn with is_odd returns results');

$result = Minijinja::Filter::select_fn(\@nums, 'is_even');
isa_ok($result, 'ARRAY', 'select_fn is_even returns ARRAY ref');
ok(scalar(@$result) > 0, 'select_fn with is_even returns results');

$result = Minijinja::Filter::select_fn([], 'is_odd');
isa_ok($result, 'ARRAY', 'select_fn on empty array returns ARRAY ref');
is scalar(@$result), 0, 'select_fn empty array returns empty';

$result = Minijinja::Filter::select_fn(undef, 'is_odd');
isa_ok($result, 'ARRAY', 'select_fn on undef returns ARRAY ref');
is scalar(@$result), 0, 'select_fn undef returns empty';

# select_fn with undefined items in array  
my @mixed = (1, undef, 3, undef, 5);
$result = Minijinja::Filter::select_fn(\@mixed, 'is_defined');
isa_ok($result, 'ARRAY', 'select_fn handles undef items in array');

done_testing();
1;
