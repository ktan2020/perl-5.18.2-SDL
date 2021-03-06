package Moose::Exception::CouldNotFindTypeConstraintToCoerceFrom;
BEGIN {
  $Moose::Exception::CouldNotFindTypeConstraintToCoerceFrom::AUTHORITY = 'cpan:STEVAN';
}
$Moose::Exception::CouldNotFindTypeConstraintToCoerceFrom::VERSION = '2.1204';
use Moose;
extends 'Moose::Exception';
with 'Moose::Exception::Role::Instance';

has 'constraint_name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

sub _build_message {
    my $self = shift;
    "Could not find the type constraint (".$self->constraint_name.") to coerce from";
}

1;
