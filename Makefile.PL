use strict; use warnings;

use ExtUtils::MakeMaker;
use Config;

# Allow environment variables to override default paths  
my $minijinja_src_dir = $ENV{'MINIJINJA_SRC'} || 'minijinja';
my $lib_dir = "$minijinja_src_dir/target/release"; 
my $inc_dir = "$minijinja_src_dir/minijinja-cabi/include";
my $r_path  = $ENV{MINIJINJA_RPATH} || "$minijinja_src_dir/target/release";

WriteMakefile(
    NAME                => 'Minijinja',
    VERSION_FROM        => 'lib/Minijinja.pm',
    LIBS                => ["-L$lib_dir -lminijinja_cabi"],
    CCFLAGS             => "$Config{ccflags} -Wextra -Werror -fPIC -rdynamic",
    LDDLFLAGS           => "-shared -Wl,--disable-new-dtags -L$lib_dir -Wl,-R$r_path -Wl,-rpath=$r_path",
    OPTIMIZE            => '-Os',
    MAN1PODS            => {},
    MAN3PODS            => {},
    DEFINE              => '-UXS_APIVERSION_BOOTCHECK -UXS_VERSION_BOOTCHECK',
    INC                 => "-I$inc_dir -I. -DMINIJINJA_INCLUDE_DIR=$inc_dir",
    NO_META             => 1,
    PL_FILES            => {},
    NO_MYMETA           => 1,
    NO_PERLLOCAL        => 1,
    NO_PACKLIST         => 1,
    NEEDS_LINKING       => 1,
    XSMULTI             => 1,
    BUILD_REQUIRES      => {"ExtUtils::MakeMaker" => '7.12'},
    XS                  => {
        'lib/Minijinja.xs'  => 'lib/Minijinja.c',
    },
    CC                  => 'g++',
    LD                  => 'g++',
    TESTS               => 't/*.t',
    HARNESS_OPTIONS     => 'j16',
    test                => {
        HARNESS_PERL_SWITCHES => '-MDevel::Cover',
    },
    dist                => {
        COMPRESS        => 'gzip -9f',
        SUFFIX          => 'gz'
    },
);

sub MY::postamble {
    return <<'MAKE_FRAG';
testcover: pure_all
	HARNESS_PERL_SWITCHES=-MDevel::Cover prove -b -v t/
	cover
MAKE_FRAG
}
