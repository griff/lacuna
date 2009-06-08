#!/usr/bin/perl

# mklibs.pl
# by Manuel Kasper <mk@neon1.net>
#
# walks a tree and extracts library dependencies
# by using ldd
# outputs a list of all libraries required for those binaries,
# suitable for use with mkmini.pl
#
# check out my guide at http://neon1.net/
#
# arguments: tree

use File::Find;

exit unless $#ARGV == 0;

undef @liblist;

# check_libs(path)
sub check_libs {
	@filestat = stat($File::Find::name);
	
	# process only if it's a regular file, executable and not a kernel module
	if ((($filestat[2] & 0170000) == 0100000) &&
		($filestat[2] & 0111) && (!/.ko$/)) {

		@curlibs = qx{/usr/bin/ldd -f "%p\n" $File::Find::name 2>/dev/null};
		
		push(@liblist, @curlibs);
	}
}

# walk the directory tree
find(\&check_libs, $ARGV[0]);

# throw out dupes
undef %hlib;
@hlib{@liblist} = ();
@liblist = sort keys %hlib;

# remove leading slash
foreach $lib (@liblist) {
	$lib = substr($lib, 1);
}

print @liblist;
