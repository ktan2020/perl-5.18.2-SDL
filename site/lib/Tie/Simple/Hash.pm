package Tie::Simple::Hash;

use strict;
use warnings;

our $VERSION = '1.03';

use base qw(Tie::Hash Tie::Simple);

# Copyright 2004 Andrew Sterling Hanenkamp. All Rights Reserved. This software
# is made available under the same terms as Perl itself.

sub _doit {
	my $self = shift;
	Tie::Simple::Util::_doit($self, 'Tie::Hash', @_);
}

sub FETCH { shift->_doit('FETCH', @_) }
sub STORE { shift->_doit('STORE', @_) }
sub DELETE { shift->_doit('DELETE', @_) }
sub CLEAR { shift->_doit('CLEAR') }
sub EXISTS { shift->_doit('EXISTS', @_) }
sub FIRSTKEY { shift->_doit('FIRSTKEY') }
sub NEXTKEY { shift->_doit('NEXTKEY', @_) }
sub UNTIE { shift->_doit('UNTIE') }
sub DESTROY { shift->_doit('DESTROY') }

1
