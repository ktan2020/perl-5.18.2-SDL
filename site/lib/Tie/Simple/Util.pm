package Tie::Simple::Util;

use strict;
use warnings;

our $VERSION = '1.01';

# Copyright 2004 Andrew Sterling Hanenkamp. All Rights Reserved. This software
# is made available under the same terms as Perl itself.

sub _doit {
	my $self = shift;
	my $parent = shift;
	my $method = shift;

	if (defined $$self{subs}{$method}) {
		$$self{subs}{$method}->($$self{data}, @_);
	} elsif ($parent->can($method)) {
		no strict 'refs';
		my $sub = "$parent\::$method";
		&{$sub}($self, @_);
	}
}

1
