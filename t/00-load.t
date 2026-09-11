use strict; use warnings;
use Test::More tests => 3;

use_ok('Minijinja') or BAIL_OUT("Cannot load Minijinja");

# Check if we can instantiate environment
my $env;
eval { 
    $env = Minijinja->minijinja();
};
is($@, "", "Environment creation eval ok");
ok(defined $env, "Environment creation defined");
done_testing();

1;
