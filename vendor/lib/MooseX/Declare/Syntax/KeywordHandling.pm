package MooseX::Declare::Syntax::KeywordHandling;
{
  $MooseX::Declare::Syntax::KeywordHandling::VERSION = '0.38';
}
BEGIN {
  $MooseX::Declare::Syntax::KeywordHandling::AUTHORITY = 'cpan:FLORA';
}
# ABSTRACT: Basic keyword functionality

use Moose::Role;
use Moose::Util::TypeConstraints;
use Devel::Declare ();
use Sub::Install qw( install_sub );
use Moose::Meta::Class ();
use List::MoreUtils qw( uniq );
use Module::Runtime 'use_module';

use aliased 'MooseX::Declare::Context';

use namespace::clean -except => 'meta';


requires qw(
    parse
);


has identifier => (
    is          => 'ro',
    isa         => subtype(as 'Str', where { /^ [_a-z] [_a-z0-9]* $/ix }),
    required    => 1,
);


sub get_identifier { shift->identifier }

sub context_class { Context }

sub context_traits { }


sub setup_for {
    my ($self, $setup_class, %args) = @_;

    # make sure the stack is valid
    my $stack = $args{stack} || [];
    my $ident = $self->get_identifier;

    # setup the D:D handler for our keyword
    Devel::Declare->setup_for($setup_class, {
        $ident => {
            const => sub { $self->parse_declaration((caller(1))[1], \%args, @_) },
        },
    });

    # search or generate a real export
    my $export = $self->can('generate_export') ? $self->generate_export($setup_class) : sub { };

    # export subroutine
    install_sub({
        code    => $export,
        into    => $setup_class,
        as      => $ident,
    }) unless $setup_class->can($ident);

    return 1;
}


sub parse_declaration {
    my ($self, $caller_file, $args, @ctx_args) = @_;

    # find and load context object class
    my $ctx_class = $self->context_class;
    use_module $ctx_class;

    # do we have traits?
    if (my @ctx_traits = uniq $self->context_traits) {

        use_module $_
            for @ctx_traits;

        $ctx_class = Moose::Meta::Class->create_anon_class(
            superclasses => [$ctx_class],
            roles        => [@ctx_traits],
            cache        => 1,
        )->name;
    }

    # create a context object and initialize it
    my $ctx = $ctx_class->new(
        %{ $args },
        caller_file => $caller_file,
    );
    $ctx->init(@ctx_args);

    # parse with current context
    return $self->parse($ctx);
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MooseX::Declare::Syntax::KeywordHandling - Basic keyword functionality

=head1 DESCRIPTION

This role provides the functionality common for all keyword handlers
in L<MooseX::Declare>.

=head1 ATTRIBUTES

=head2 identifier

This is the name of the actual keyword. It is a required string that is in
the same format as a usual Perl identifier.

=head1 METHODS

=head2 get_identifier

  Str Object->get_identifier ()

Returns the name the handler will be setup under.

=head2 setup_for

  Object->setup_for (ClassName $class, %args)

This will setup the handler in the specified C<$class>. The handler will
dispatch to the L</parse_declaration> method when the keyword is used.

A normal code reference will also be exported into the calling namespace.
It will either be empty or, if a C<generate_export> method is provided,
the return value of that method.

=head2 parse_declaration

  Object->parse_declaration (Str $filename, HashRef $setup_args, @call_args)

This simply creates a new L<context|MooseX::Declare::Context> and passes it
to the L</parse> method.

=head1 REQUIRED METHODS

=head2 parse

  Object->parse (Object $context)

This method must implement the actual parsing of the keyword syntax.

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
