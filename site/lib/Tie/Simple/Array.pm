package Tie::Simple::Array;

use strict;
use warnings;

our $VERSION = '1.01';

use base qw(Tie::Array Tie::Simple);

# Copyright 2004 Andrew Sterling Hanenkamp. All Rights Reserved. This software
# is made available under the same terms as Perl itself.

sub _doit {
	my $self = shift;
	Tie::Simple::Util::_doit($self, 'Tie::Array', @_);
}

sub FETCH     { shift->_doit('FETCH', @_) }
sub STORE     { shift->_doit('STORE', @_) }
sub FETCHSIZE { shift->_doit('FETCHSIZE') }
sub STORESIZE { shift->_doit('STORESIZE', @_) }
sub EXTEND    { shift->_doit('EXTEND', @_) }
sub EXISTS    { shift->_doit('EXISTS', @_) }
sub DELETE    { shift->_doit('DELETE', @_) }
sub CLEAR     { shift->_doit('CLEAR') }
sub PUSH      { shift->_doit('PUSH', @_) }
sub POP       { shift->_doit('POP') }
sub SHIFT     { shift->_doit('SHIFT') }
sub UNSHIFT   { shift->_doit('UNSHIFT', @_) }
sub SPLICE    { shift->_doit('SPLICE', @_) }
sub UNTIE     { shift->_doit('UNTIE') }
sub DESTROY   { shift->_doit('DESTROY') }

1
