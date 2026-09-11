use strict; use warnings;

BEGIN {
    if (!$ENV{COVERAGE}) {
        print "1..0\n";
        print "# Set COVERAGE=1 to run coverage tests\n";
        exit 0;
    }
}

use Test::More;
use FindBin;

my $has_cover = 0;
eval {
    require Devel::Cover;
    Devel::Cover->import();
    Devel::Cover->VERSION(0.0);
    $has_cover = 1
};
if (!$has_cover) {
    print "ok 1 - Devel::Cover not available, skipping\n";
    print "1..1\n";
    exit 0;
}

Devel::Cover::set_coverage("all");

chdir("$FindBin::Bin/..") || die "Error chdir: $!\n";
my @test_files =
    sort
    grep {$_ ne "" && -f $_ && -r $_}
    map {glob $_}
        'lib/*.pm',
        't/*.t',
        't/lib/*.pm',
        'scripts/*.pl';
ok(@test_files > 0, "found test files to cover (".scalar(@test_files).")");

use_ok("Minijinja");

Devel::Cover::set_coverage('none');
Devel::Cover::get_coverage();

done_testing();

1;
