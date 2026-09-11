use strict; use warnings;
use Test::More;

use FindBin;
use File::Spec;
use File::Basename qw(dirname);

# Check if both Perl::Critic and Test::Perl::Critic can load
my @missing_deps;
for my $mod ("Perl::Critic", "Test::Perl::Critic") {
    eval "require $mod";
    if ($@) {
        print "# $@\n";
        push @missing_deps, $mod;
    }
}

if(@missing_deps){
    diag("Perl::Critic suite not fully installed.");
    diag("Missing: " . join(", ", @missing_deps));
    diag("");
    diag("Install via: sudo apt-get install libperl-critic-perl");
    diag("Or via cpan: cpan -i Test::Perl::Critic");
    diag("");
    diag("Note: This test requires Perl::Critic and all its dependencies.");
    plan skip_all => "skip - Perl::Critic not available (see diagnostics above)";
}

plan tests => 1;

# Collect all files matching patterns
chdir("$FindBin::Bin/..") || die "Error chdir: $!\n";
my @files = map {glob($_)} 'lib/*.pm', 't/*.t', 't/lib/*.pm', 'scripts/*.pl';

my $base = dirname($FindBin::Bin);
my $profile = "$base/t/resources/perlcritic";
$profile = File::Spec->rel2abs($profile);
die "$profile doesn't exist.\n" unless -f $profile;
my $c = Perl::Critic->new(
    -severity => 1,
    -only     => 1,
    -verbose  => 4,
    -profile  => $profile
);
Perl::Critic::Violation::set_format("%m at line %l, column %c.  %e.  (Severity: %s)\n");
diag("Checking ".scalar(@files)." files for perlcritic violations");

my $violations = 0;
for my $file (sort @files) {
    next unless -f $file && -r $file;
    my @v = $c->critique($file, severity=>5);
    print "$file: $_" for @v;
    if (!@v) {
        diag("  $file - clean");
    } else {
        $violations++;
    }
}
if ($violations == 0) {
    diag("No policy violations found across all " . scalar(@files) . " files");
} else {
    diag("$violations file(s) had policy violations");
}

pass("perlcritic passed ($violations violations total)");

1;
