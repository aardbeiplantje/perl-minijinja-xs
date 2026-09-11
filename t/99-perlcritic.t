use strict; use warnings;
use Test::More;

# Check if required modules can load
my @missing_deps;
for my $mod ("Perl::Critic", "Perl::Critic::Utils", "MCE::Grep") {
    eval "require $mod";
    if ($@) {
        print "# $@\n";
        push @missing_deps, $mod;
    }
}

if(@missing_deps){
    diag("Required modules not fully installed.");
    diag("Missing: " . join(", ", @missing_deps));
    diag("");
    diag("Install via: cpan -i MCE Perl::Critic");
    diag("");
    plan skip_all => "skip - required modules not available (see diagnostics above)";
}

use FindBin;
use File::Spec;
use File::Basename qw(dirname);
use MCE::Grep max_workers => 20, chunk_size => 10;

my $base = dirname($FindBin::Bin);
my $profile = "$base/t/resources/perlcritic";
$profile = File::Spec->rel2abs($profile);
die "$profile doesn't exist.\n" unless -f $profile;

sub is_critic_clean {
    my ($file) = @_;
    print "# test $file\n";
    return unless length($file//"") and -f $file;
    my $c = Perl::Critic->new(
        -severity => 1,
        -only     => 1,
        -verbose  => 4,
        -profile  => $profile,
    );
    my @v = $c->critique($file, severity=>5);
    is_deeply(\@v, [], "$file - clean");
    if (@v) {
        diag("  Violations in $file:\n" . join("", map {"    $_\n"} @v));
        return;  # undef → filtered out by mce
    }
    return 1;  # true → kept by mce
}

# Collect all files matching patterns
chdir("$FindBin::Bin/..") || die "Error chdir: $!\n";
my @files =
    sort
    grep {$_ ne "" && -f $_ && -r $_}
    map {glob $_}
        'lib/*.pm',
        't/*.t',
        't/lib/*.pm',
        'scripts/*.pl';
die "Nothing to critique" unless @files;

diag("Checking ".scalar(@files)." files for perlcritic violations");

my $tb = Test::More->builder();
$tb->use_numbers(0);
$tb->no_ending(1);
my $okays = mce_grep {is_critic_clean($_)} @files;
my $pass = ($okays == @files)||0;
ok($pass, "pass ok");
$tb->done_testing(1+scalar @files);

1;
