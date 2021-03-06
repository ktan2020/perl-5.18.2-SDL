package MooseX::Declare::Context::Parameterized;
{
  $MooseX::Declare::Context::Parameterized::VERSION = '0.38';
}
BEGIN {
  $MooseX::Declare::Context::Parameterized::AUTHORITY = 'cpan:FLORA';
}
# ABSTRACT: context for parsing optionally parameterized statements

use Moose::Role;
use MooseX::Types::Moose qw/Str HashRef/;

use namespace::autoclean;


has parameter_signature => (
    is        => 'rw',
    isa       => Str,
    predicate => 'has_parameter_signature',
);


has parameters => (
    traits    => ['Hash'],
    isa       => HashRef,
    default   => sub { {} },
    handles   => {
        add_parameter  => 'set',
        get_parameters => 'kv',
    },
);


sub strip_parameter_signature {
    my ($self) = @_;

    my $signature = $self->strip_proto;

    $self->parameter_signature($signature)
        if defined $signature && length $signature;

    return $signature;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MooseX::Declare::Context::Parameterized - context for parsing optionally parameterized statements

=head1 DESCRIPTION

This context trait will add optional parameterization functionality to the
context.

=head1 ATTRIBUTES

=head2 parameter_signature

This will be set when the C<strip_parameter_signature> method is called and it
was able to extract a list of parameterisations.

=head1 METHODS

=head2 has_parameter_signature

Predicate method for the C<parameter_signature> attribute.

=head2 add_parameter

Allows storing parameters extracted from C<parameter_signature> to be used
later on.

=head2 get_parameters

Returns all previously added parameters.

=head2 strip_parameter_signature

  Maybe[Str] Object->strip_parameter_signature()

This method is intended to parse the main namespace of a namespaced keyword.
It will use L<Devel::Declare::Context::Simple>s C<strip_word> method and store
the result in the L</namespace> attribute if true.

=head1 SEE ALSO

=over 4

=item *

L<MooseX::Declare>

=item *

L<MooseX::Declare::Context>

=back

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
