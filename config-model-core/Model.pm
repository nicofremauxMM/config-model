# $Author: ddumont $
# $Date: 2007-09-06 11:23:25 $
# $Name: not supported by cvs2svn $
# $Revision: 1.36 $

#    Copyright (c) 2005-2007 Dominique Dumont.
#
#    This file is part of Config-Model.
#
#    Config-Model is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser Public License as
#    published by the Free Software Foundation; either version 2.1 of
#    the License, or (at your option) any later version.
#
#    Config-Model is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser Public License for more details.
#
#    You should have received a copy of the GNU Lesser Public License
#    along with Config-Model; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA

package Config::Model ;
require Exporter;
use Carp;
use strict;
use warnings FATAL => qw(all);
use vars qw/@ISA @EXPORT @EXPORT_OK $VERSION/;
use Storable ('dclone') ;
use Data::Dumper ();

use Config::Model::Instance ;

# this class holds the version number of the package
use vars qw($VERSION @status @level @permission_list %permission_index) ;

$VERSION = '0.612';

=head1 NAME

Config::Model - Model to create configuration validation tool

=head1 SYNOPSIS

 # create new Model object
 my $model = Config::Model->new() ;

 # create config model
 $model ->create_config_class 
  (
   name => "SomeRootClass",
   element => [ ...  ]
  ) ;

 # create instance 
 my $instance = $model->instance (root_class_name => 'SomeRootClass', 
                                  instance_name => 'test1');

 # get configuration tree root
 my $cfg_root = $instance -> config_root ;

 # You can also use load on demand
 my $model = Config::Model->new() ;

 # this call will look for a AnotherClass.pl that will contain
 # the model
 my $inst2 = $model->instance (root_class_name => 'AnotherClass', 
                              instance_name => 'test2');

 # then get configuration tree root
 my $cfg_root = $inst2 -> config_root ;

=head1 DESCRIPTION

Using Config::Model, a typical configuration validation tool will be
made of 3 parts :

=over

=item 1

The user interface

=item 2

The validation engine which is in charge of validating all the
configuration information provided by the user.

=item 3

The storage facility that store the configuration information

=back

C<Config::Model> provides a B<validation engine> according to a set of
rules.

=head1 User interface

The user interface will use some parts of the API to set and get
configuration values. More importantly, a generic user interface will
need to explore the configuration model to be able to generate at
run-time relevant configuration screens.

A generic Curses interface is under development. More on this later.

One can also consider to use Webmin (L<http://www.webmin.com>) on top
of config model.

=head1 Storage

The storage will often be a way to store configuration in usual
configuration files, like C</etc/X11/xorg.conf>

One can also consider storing configuration data in a database, ldap
directory or using elektra project L<http://www.libelektra.org/>

=head1 Validation engine

C<Config::Model> provides a way to get a validation engine from a set
of rules. This set of rules is now called the configuration model. 

=head1 Configuration Model

Before talking about a configuration tree, we must create a
configuration model that will set all the properties of the validation
engine you want to create.

=head2 Constructor

Simply call new without parameters:

 my $model = Config::Model -> new ;

This will create an empty shell for your model.

=cut

sub new {
    my $type = shift ;
    my %args = @_;

    my $skip =  $args{skip_include} || 0 ;

    if (defined $args{skip_inheritance}) {
	carp "skip_inheritance is deprecated, use skip_include" ;
	$skip = $args{skip_inheritance} ;
    }

    bless {
	   model_dir => $args{model_dir} ,
	   skip_include => $skip,
	  },$type;
}

=head2 declaring the model

The configuration model is expressed in a declarative form (i.e. a
Perl data structure which is always easier to maintain than a lot of
code.)

Each node of the configuration tree is attached to a configuration
class whose properties you must declare by calling
L</"create_config_class">.

Each configuration class contains mostly 2 types of elements:

=over

=item *

A node type element that will refer to another configuration class

=item *

A value element that will contains actual configuration data

=back

By declaring a set of configuration classes and refering them in node
element, you will shape the structure of your configuration tree.

The structure of the configuration data must be based on a tree
structure. This structure has several advantages:

=over

=item *

Unique path to get to a node or a leaf.

=item *

Simpler exploration and query

=item *

Simple hierarchy. Deletion of configuration items is simpler to grasp:
when you cut a branch, all the leaves attaches to that branch go down.

=back

But using a tree has also some drawbacks:

=over 4

=item *

A complex configuration cannot be mapped on a simple tree.  Some more
relation between nodes and leaves must be added.

=item *

Some configuration part are actually graph instead of a tree (for
instance, any configuration that will map a service to a
resource). The graph relation must be decomposed in a tree with
special I<reference> relation. See L<Config::Model::Value/Value Reference>

=back

Note: a configuration tree is a tree of objects. The model is declared
with classes. The classes themselves have relations that closely match
the relation of the object of the configuration tree. But the class
need not to be declared in a tree structure (always better to reuse
classes). But they must be declared as a DAG (directed acyclic graph).

=begin html

<a href="http://en.wikipedia.org/wiki/Directed_acyclic_graph">More on DAGs</a>

=end html

Each configuration class declaration specifies:

=over 8

=item *

Most importantly, the type of the element (mostly C<leaf>, or C<node>)

=item *

The properties of each element (boundaries, check, integer or string,
enum like type ...)

=item *

The default values of parameters (if any)

=item *

Mandatory parameters

=item *

Targeted audience (intermediate, advance, master)

=item *

On-line help (for each parameter or value of parameter)

=item *

The level of expertise of each parameter (to hide expert parameters
from newbie eyes)

=back

See L<Config::Model::Node> for details on how to declare a
configuration class.

=cut


=head1 Configuration instance

A configuration instance if the staring point of a configuration tree.
When creating a model instance, you must specify the root class name, I.e. the
configuration class that is used by the root node of the tree. 

 my $model = Config::Model->new() ;
 $model ->create_config_class 
  (
   name => "SomeRootClass",
   element => [ ...  ]
  ) ;

 my $inst = $model->instance (root_class_name => 'SomeRootClass', 
                              instance_name => 'test1');

You can create several separated instances from a model.

When using autoread or autowrite feature

=cut

sub instance {
    my $self = shift ;
    my %args = @_ ;

    my $instance_name =  delete $args{instance_name} || delete $args{name} ;

    croak "Model: can't create or retrieve instance without instance_name"
      unless defined $instance_name ;

    if (defined $self->{instance}{$instance_name}) {
	return $self->{instance}{$instance_name} ;
    }

    my $root_class_name = delete $args{root_class_name}
      or croak "Model: can't create instance without root_class_name ";


    if (defined $args{model_file}) {
	my $file = delete $args{model_file} ;
	$self->load($root_class_name, $file) ;
    }

    my $i = Config::Model::Instance 
      -> new (config_model => $self,
	      root_class_name => $root_class_name,
	      name => $instance_name ,
	      %args                 # for optional parameters like *directory
	     ) ;

    $self->{instance}{$instance_name} = $i ;
    return $i ;
}

sub instance_names {
    my $self = shift ;
    return keys %{$self->{instance}} ;
}

=head1 Configuration class

A configuration class is made of series of elements which are detailed
in L<Config::Model::Node>.

Whatever its type (node, leaf,... ), each element of a node has
several other properties:

=over

=item permission

By using the C<permission> parameter, you can change the permission
level of each element. Authorized privilege values are C<master>,
C<advanced> and C<intermediate> (default).

=cut

@permission_list = qw/intermediate advanced master/;

=item level

Level is C<important>, C<normal> or C<hidden>. 

The level is used to set how configuration data is presented to the
user in browsing mode. C<Important> elements will be shown to the user
no matter what. C<hidden> elements will be explained with the I<warp>
notion.

=cut

@level = qw/hidden normal important/;

=item status

Status is C<obsolete>, C<deprecated> or C<standard> (default).

Using a deprecated element will issue a warning. Using an obsolete
element will raise an exception.

=cut

@status = qw/obsolete deprecated standard/;

=item description

Description of the element. This description will be used when
generating user interfaces.

=item class_description

Description of the configuration class. This description will be used
when generating user interfaces.

=cut


my %default_property =
  (
   status      => 'standard',
   level       => 'normal',
   permission  => 'intermediate',
   description => ''
  );

my %check;

{
  my $idx = 0 ;
  map ($check{level}{$_}=$idx++, @level);
  $idx = 0 ;
  map ($check{status}{$_}=$idx++, @status);
  $idx = 0 ;
  map ($permission_index{$_}=$idx++, @permission_list);
}

$check{permission}=\%permission_index ;

# unpacked model is:
# {
#   element_list  => [ ... ],
#   permission    => { element_name => <permission> },
#   status        => { element_name => <status>     },
#   description   => { element_name => <string> },
#   element       => { element_name => element_data (left as is)    },
#   class_description => <class description string>,
#   level         => { element_name => <level like important or normal..> },
#   include       => 'class_name',
#   include_after => 'element_name',
# }

=item generated_by

Mention with a descriptive string if this class was generated by a program.
This parameter is currently reserved for a model editor (yet to be written).

=cut

my @legal_params = qw/permission status description element level config_dir 
                      generated_by class_description/;

sub create_config_class {
    my $self=shift ;
    my %raw_model = @_ ;

    my $config_class_name = delete $raw_model{name} or
      croak "create_one_config_class: no config class name" ;

    if (exists $self->{model}{$config_class_name}) {
	Config::Model::Exception::ModelDeclaration->throw
	    (
	     error=> "create_one_config_class: attempt to clobber $config_class_name".
	     "config class name "
	    );
    }

    if (defined $raw_model{inherit_after}) {
	warn "Model $config_class_name: inherit_after is deprecated ",
	  "in favor of include_after\n";
	$raw_model{include_after} = delete $raw_model{inherit_after} ;
    }
    if (defined $raw_model{inherit}) {
	warn "Model $config_class_name: inherit is deprecated in favor of include\n";
	$raw_model{include} = delete $raw_model{inherit} ;
    }

    $self->{raw_model}{$config_class_name} = \%raw_model ;

    # perform some syntax and rule checks and expand compacted
    # elements ie  [qw/foo bar/] => {...} is transformed into
    #  foo => {...} , bar => {...} before being stored

    my $raw_copy = dclone \%raw_model ;
    my %model = ( element_list => [] );


    # add included items
    if ($self->{skip_include}) {
	$model{include}       = delete $raw_copy->{include} ;
	$model{include_after} = delete $raw_copy->{include_after} ;
    }
    else {
	$self->include_class($raw_copy) ; 
    }


    # check config class parameters
    $self->check_class_parameters($config_class_name, \%model, $raw_copy) ;

    my @left_params = keys %$raw_copy ;
    Config::Model::Exception::ModelDeclaration->throw
        (
         error=> "create class $config_class_name: unknown ".
	 "parameter '" . join("', '",@left_params)."', expected '".
	 join("', '",@legal_params,qw/class_description/)."'"
        )
	  if @left_params ;


    $self->{model}{$config_class_name} = \%model ;

    return $config_class_name ;
}

sub check_class_parameters {
    my $self  = shift;
    my $config_class_name = shift;
    my $model = shift || die ;
    my $raw_model = shift || die ;

    my @element_list ;

    # first get the element list
    my @compact_list = @{$raw_model->{element} || []} ;
    while (@compact_list) {
	my ($item,$info) = splice @compact_list,0,2 ;
	# store the order of element as declared in 'element'
	push @element_list, ref($item) ? @$item : ($item) ;
    }

    # get data read/write information (if any)
    $model->{read_config_dir} = $model->{write_config_dir}
      = delete $raw_model->{config_dir} ;
    foreach my $rw_info (qw/read_config  read_config_dir 
                            write_config write_config_dir/) {
	next unless defined $raw_model->{$rw_info} ;
	$model->{$rw_info} = delete $raw_model->{$rw_info} ;
    }

    # this parameter is filled by class generated by a program. It may
    # be used to avoid interactive edition of a generated model
    $model->{generated_by} = delete $raw_model->{generated_by} ;

    # class_description cannot be handled in the next loop
    $model->{class_description} = delete $raw_model->{class_description} 
      if defined $raw_model->{class_description}  ;


    # check for duplicate in @element_list.
    my %check_list ;
    map { $check_list{$_}++ } @element_list ;
    my @extra = grep { $check_list{$_} > 1 } keys %check_list ;
    if (@extra) {
	Config::Model::Exception::ModelDeclaration->throw
	    (
	     error=> "class $config_class_name: @extra element ".
	              "is declared more than once. Check the included parts"
	    ) ;
    }

    foreach my $info_name (@legal_params) {
	# fill default info
	map {$model->{$info_name}{$_} = $default_property{$info_name}; }
	  @element_list 
	    if defined $default_property{$info_name};

	my $compact_info = delete $raw_model->{$info_name} ;
	next unless defined $compact_info ;

	Config::Model::Exception::ModelDeclaration->throw
	    (
	     error=> "Data for parameter $info_name of $config_class_name"
	     ." is not an array ref"
	    ) unless ref($compact_info) eq 'ARRAY' ;

	my @info = @$compact_info ; 
	while (@info) {
	    my ($item,$info) = splice @info,0,2 ;
	    my @element_names = ref($item) ? @$item : ($item) ;

	    Config::Model::Exception::ModelDeclaration->throw
		(
		 error=> "create class $config_class_name: unknown ".
		 "value for $info_name: '$info'. Expected '".
		 join("', '",keys %{$check{$info_name}})."'"
		)
		  if defined $check{$info_name} 
		    and not defined $check{$info_name}{$info} ;

	    # warp can be found only in element item
	    if (ref $info eq 'HASH') {
		if (defined $info->{warp}) {
		    $self->translate_warp_info($element_names[0], $info->{warp});
		}
		elsif (defined $info->{type} && $info->{type} eq 'warped_node') {
		    $self->translate_warp_info($element_names[0], $info);
		}
	    }

	    foreach my $name (@element_names) {
		$model->{$info_name}{$name} = $info ;
	    }
	}
    }

    Config::Model::Exception::ModelDeclaration->throw
	(
	 error => "create class $config_class_name: unexpected "
	        . "parameters '". join (', ', keys %$raw_model) ."' "
	        . "Expected '".join("', '",@legal_params)."'"
	)
	  if keys %$raw_model ;

    $model->{element_list} = \@element_list;
}

# internal: translate warp information into 'boolean expr' => { ... }
sub translate_warp_info {
    my $self = shift ;
    my $elt_name = shift ;
    my $warp_info = shift ;

    print "translate_warp_info $elt_name input:\n", 
      Data::Dumper->Dump( [$warp_info ] , [qw/warp_info/ ]) ,"\n"
	  if $::debug ;

    my $follow = $self->translate_follow_arg($elt_name,$warp_info->{follow}) ;

    # now, follow is only { w1 => 'warp1', w2 => 'warp2'}
    my @warper_items = values %$follow ;

    my $multi_follow =  @warper_items > 1 ? 1 : 0;

    my $rules = $self->translate_rules_arg($elt_name,
					   \@warper_items, $warp_info->{rules});

    $warp_info->{follow} = $follow;
    $warp_info->{rules}  = $rules ;

    print "translate_warp_info $elt_name output:\n",
      Data::Dumper->Dump([$warp_info ] , [qw/new_warp_info/ ] ) ,"\n"
	  if $::debug ;
}

# internal
sub translate_multi_follow_legacy_rules {
    my ($self,  $elt_name , $warper_items, $raw_rules) = @_ ;
    my @rules ;

    # we have more than one warper_items

    for (my $r_idx = 0; $r_idx < $#$raw_rules; $r_idx  += 2) {
	my $key_set = $raw_rules->[$r_idx] ;
	my @keys = ref($key_set) ? @$key_set : ($key_set) ;

	# legacy: check the number of keys in the @rules set 
	if ( @keys != @$warper_items and $key_set !~ / eq /) {
	    Config::Model::Exception::ModelDeclaration
		-> throw (
			  error => "Warp rule error in object '$elt_name'"
			        . ": Wrong nb of keys in set '@keys',"
			        . " Expected " . scalar @$warper_items . " keys"
			 )  ;
	}
	# legacy:
	# if a key of a rule (e.g. f1 or b1) is an array ref, all the
	# values passed in the array are considered as valid.
	# i.e. [ [ f1a, f1b] , b1 ] => { ... }
	# is equivalent to 
	# [ f1a, b1 ] => { ... }, [  f1b , b1 ] => { ... }
	
	# now translate [ [ f1a, f1b] , b1 ] => { ... }
	# into "( $f1 eq f1a or $f1 eq f1b ) and $f2 eq b1)" => { ... }
	my @bool_expr ;
	my $b_idx = 0;
	foreach my $key (@keys) {
	    if (ref $key ) {
		my @expr = map { "\$f$b_idx eq '$_'" } @$key ;
		push @bool_expr , "(" . join (" or ", @expr ). ")" ;
	    }
	    elsif ($key !~ / eq /) {
		push @bool_expr, "\$f$b_idx eq '$key'" ;
	    }
	    else {
		push @bool_expr, $key ;
	    }
	    $b_idx ++ ;
	}
	push @rules , join ( ' and ', @bool_expr),  $raw_rules->[$r_idx+1] ;
    }
    return @rules ;
}

sub translate_follow_arg {
    my $self = shift ;
    my $elt_name = shift ;
    my $raw_follow = shift ;

    if (ref($raw_follow) eq 'HASH') {
	# follow is { w1 => 'warp1', w2 => 'warp2'} 
	return $raw_follow ;
    }
    elsif (ref($raw_follow) eq 'ARRAY') {
	# translate legacy follow arguments ['warp1','warp2',...]
	my $follow = {} ;
	my $idx = 0;
	map { $follow->{'f' . $idx++ } = $_ } @$raw_follow ;
	return $follow ;
    }
    else {
	# follow is a simple string
	return { f1 => $raw_follow } ;
    }
}

sub translate_rules_arg {
    my $self = shift ;
    my $elt_name = shift ;
    my $warper_items = shift ;
    my $raw_rules = shift ;

    my $multi_follow =  @$warper_items > 1 ? 1 : 0;

    # $rules is either:
    # { f1 => { ... } }  (  may be [ f1 => { ... } ] ?? )
    # [ 'boolean expr' => { ... } ]
    # legacy:
    # [ f1, b1 ] => {..} ,[ f1,b2 ] => {...}, [f2,b1] => {...} ...
    # foo => {...} , bar => {...}
    my @rules ;
    if (ref($raw_rules) eq 'HASH') {
	# transform the simple hash { foo => { ...} }
	# into array ref [ '$f1 eq foo' => { ... } ]
	my $h = $raw_rules ;
	@rules = map { ( "\$f1 eq '$_'" , $h->{$_} ) } keys %$h ;
    } 
    elsif (ref($raw_rules) eq 'ARRAY') {
	if ( $multi_follow ) {
	    push @rules, 
	      $self->translate_multi_follow_legacy_rules( $elt_name, $warper_items,
							  $raw_rules ) ;
	}
	else {
	    # now translate [ f1a, f1b]  => { ... }
	    # into "$f1 eq f1a or $f1 eq f1b " => { ... }
	    my @raw_rules = @{$raw_rules} ;
	    for (my $r_idx = 0; $r_idx < $#raw_rules; $r_idx  += 2) {
		my $key_set = $raw_rules[$r_idx] ;
		my @keys = ref($key_set) ? @$key_set : ($key_set) ;
		my @bool_expr = map { /\$/ ? $_ : "\$f1 eq '$_'" } @keys ;
		push @rules , join ( ' or ', @bool_expr),  $raw_rules[$r_idx+1] ;
	    }
	}
    }
    else {
	Config::Model::Exception::ModelDeclaration
	    -> throw (
		      error => "Warp rule error in object '$elt_name': "
		             . "rules must be a hash ref. Got '$raw_rules'"
		     ) ;
    }

    return \@rules ;
}


=item include

Include element description from another class. 

  include => 'AnotherClass' ,

In a configuration class, the order of the element is important. For
instance if C<foo> is warped by C<bar>, you must declare C<bar>
element before C<foo>.

When including another class, you may wish to insert the included
elements after a specific element of your including class:

  # say AnotherClass contains element xyz
  include => 'AnotherClass' ,
  include_after => "foo" ,
  element => [ bar => ... , foo => ... , baz => ... ]

Now the element of your class will be:

  ( bar , foo , xyz , baz )

=back 

=cut

sub include_class {
    my $self  = shift;
    my $raw_model = shift || die "include_class: undefined raw_model";

    my $include_class = delete $raw_model->{include} ;

    return () unless defined $include_class ;

    my $included_raw_model = dclone $self->get_raw_model($include_class) ;
    my $include_after       = delete $raw_model->{include_after} ;

    # takes care of recursive include
    $self->include_class( $included_raw_model ) ;

    my %include_item = map { $_ => 1 } @legal_params ;

    # now include element (special treatment because order is
    # important)
    if (defined $include_after and defined $included_raw_model->{element}) {
	my %elt_idx ;
	my @raw_elt = @{$raw_model->{element}} ;
	my $idx = 0 ;
	for (my $idx = 0; $idx < @raw_elt ; $idx += 2) {
	    my $elt = $raw_elt[$idx] ;
	    map { $elt_idx{$_} = $idx } ref $elt ? @$elt : ($elt) ;
	}

	if (not defined $elt_idx{$include_after}) {
	    my $msg =  "Unknown element for 'include_after': "
		        . "$include_after, expected ". join(' ', keys %elt_idx) ;
	    Config::Model::Exception::ModelDeclaration
		-> throw (error => $msg) ;
	}

	# + 2 because we splice *after* $include_after
	my $splice_idx = $elt_idx{$include_after} + 2;
	my $to_copy = delete $included_raw_model->{element} ;
	splice ( @{$raw_model->{element}}, $splice_idx, 0, @$to_copy) ;
    }

    # now included_raw_model contains all information to be merged to
    # raw_model

    my $included_model ;
    foreach my $included_item (keys %$included_raw_model) {
	if (defined $include_item{$included_item}) {
	    my $to_copy = $included_raw_model->{$included_item} ;
	    if (ref($to_copy) eq 'HASH') {
		map { $raw_model->{$included_item}{$_} = $to_copy->{$_} } 
		  keys %$to_copy ;
	    }
	    elsif (ref($to_copy) eq 'ARRAY') {
		unshift @{$raw_model->{$included_item}}, @$to_copy;
	    }
	    else {
		$raw_model->{$included_item} = $to_copy ;
	    }
	}
	else {
	    Config::Model::Exception::ModelDeclaration->throw
		(
		 error => "Cannot include '$included_item', "
		 . "expected @legal_params"
		) ;
	}
    }

}



=pod

Example:

  my $model = Config::Model -> new ;

  $model->create_config_class 
  (
   config_class_name => 'SomeRootClass',
   permission        => [ [ qw/tree_macro warp/ ] => 'advanced'] ,
   description       => [ X => 'X-ray' ],
   class_description => "SomeRootClass description",
   element           => [ ... ] 
  ) ;

Again, see L<Config::Model::Node> for more details on configuration
class declaration.

=head1 Load pre-declared model

You can also load pre-declared model.

=head2 load( <model_name> )

This method will open the model directory and execute a C<.pl>
file containing the model declaration,

This perl file must return an array ref to declare models. E.g.:

 [
  [
   name => 'Class_1',
   element => [ ... ]
  ],
  [
   name => 'Class_2',
   element => [ ... ]
  ]
 ]; 

do not put C<1;> at the end or C<load> will not work

If a model name contain a C<::> (e.g C<Foo::Bar>), C<load> will look for
a file named C<Foo/Bar.pl>.

Returns a list containining the names of the loaded classes. For instance, if 
C<Foo/Bar.pl> contains a model for C<Foo::Bar> and C<Foo::Bar2>, C<load>
will return C<( 'Foo::Bar' , 'Foo::Bar2' )>.

=cut


sub load {
    my $self = shift ;
    my $load_model = shift ;
    my $load_file = shift ;

    my $load_path = $load_model . '.pl' ;
    $load_path =~ s/::/\//g;

    $load_file ||=  ($self->{model_dir} || 'Config/Model/models') 
                 . '/'. $load_path ;

    print "Model: load model $load_file\n" if $::verbose ;

    my $model = do $load_file or
      Config::Model::Exception::ModelDeclaration
	  -> throw (
		    message => "model $load_model compile error in $load_file: "
		             . ( $! || $@)
		   );

    unless ($model) {
	warn "couldn't parse $load_file: $@" if $@;
	warn "couldn't do $load_file: $!"    unless defined $model;
	warn "couldn't run $load_file"       unless $model;
    }

    die "Model file $load_file does not return an array ref\n"
      unless ref($model) eq 'ARRAY';

    my @loaded ;
    foreach my $config_class_info (@$model) {
	my @data = ref $config_class_info eq 'HASH' ? %$config_class_info
	         : ref $config_class_info eq 'ARRAY' ? @$config_class_info
	         : croak "load $load_file: config_class_info is not a ref" ;
	push @loaded, $self->create_config_class(@data) ;
    }

    return @loaded
}

# TBD: For a proper model plugin, scan directory <model_name>.d and
# load in merge mode all pieces of model found there merge mode: model
# data is added to main model before running create_config_class

=head1 Model query

=head2 get_model( config_class_name )

Return a hash containing the model declaration.

=cut

sub get_model {
    my $self =shift ;
    my $config_class_name = shift 
      || die "Model::get_model: missing config class name argument" ;

    $self->load($config_class_name) 
      unless defined $self->{model}{$config_class_name} ;

    my $model = $self->{model}{$config_class_name} ||
      croak "get_model error: unknown config class name: $config_class_name";

    return dclone($model) ;
}

# returns a hash ref containing the raw model, i.e. before expansion of 
# multiple keys (i.e. [qw/a b c/] => ... )
# internal. For now ...
sub get_raw_model {
    my $self =shift ;
    my $config_class_name = shift ;

    $self->load($config_class_name) 
      unless defined $self->{model}{$config_class_name} ;

    my $model = $self->{raw_model}{$config_class_name} ||
      croak "get_raw_model error: unknown config class name: $config_class_name";

    return dclone($model) ;
}

=head2 get_element_name( class => Foo, for => advanced )

Get all names of the elements of class C<Foo> that are accessible for
level C<advanced>. 

Level can be C<master> (default), C<advanced> or C<intermediate>.

=cut

sub get_element_name {
    my $self = shift ;
    my %args = @_ ;

    my $class = $args{class} || 
      croak "get_element_name: missing 'class' parameter" ;
    my $for = $args{for} || 'master' ;

    croak "get_element_name: wrong 'for' parameter. Expected ", 
      join (' or ', @permission_list) 
	unless defined $permission_index{$for} ;

    my @permissions 
      = @permission_list[ 0 .. $permission_index{$for} ] ;
    my @array
      = $self->get_element_with_permission($class,@permissions);

    return wantarray ? @array : join( ' ', @array );
}

# internal
sub get_element_with_permission {
    my $self      = shift ;
    my $class     = shift ;

    my $model = $self->get_model($class) ;
    my @result ;

    # this is a bit convoluted, but the order of the returned element
    # must respect the order of the elements declared in the model by
    # the user
    foreach my $elt (@{$model->{element_list}}) {
	foreach my $permission (@_) {
	    push @result, $elt
	      if $model->{level}{$elt} ne 'hidden' 
		and $model->{permission}{$elt} eq $permission ;
	}
    }

    return @result ;
}

#internal
sub get_element_property {
    my $self = shift ;
    my %args = @_ ;

    my $elt = $args{element} || 
      croak "get_element_property: missing 'element' parameter";
    my $prop = $args{property} || 
      croak "get_element_property: missing 'property' parameter";
    my $class = $args{class} || 
      croak "get_element_property:: missing 'class' parameter";

    return $self->{model}{$class}{$prop}{$elt} ;
}

=head1 Error handling

Errors are handled with an exception mechanism (See
L<Exception::Class>).

When a strongly typed Value object gets an authorized value, it raises
an exception. If this exception is not catched, the programs exits.

See L<Config::Model::Exception|Config::Model::Exception> for details on
the various exception classes provided with C<Config::Model>.

=head1 Log and Traces

Currently a rather lame trace mechanism is provided:

=over

=item *

Set C<$::debug> to 1 to get debug messages on STDOUT.

=item *

Set C<$::verbose> to 1 to get verbose messages on STDOUT.

=back

Depending on available time, a better log/error system may be
implemented.

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model::Instance>, 

=head2 Model elements

The arrow shows the inheritance of the classes

=over

=item * 

L<Config::Model::Node> <- L<Config::Model::AutoRead> <- L<Config::Model::AnyThing> 

=item *

L<Config::Model::HashId> <- L<Config::Model::AnyId> <- L<Config::Model::WarpedThing> <- L<Config::Model::AnyThing> 

=item *

L<Config::Model::ListId> <- L<Config::Model::AnyId> <- L<Config::Model::WarpedThing> <- L<Config::Model::AnyThing> 

=item *

L<Config::Model::Value> <- L<Config::Model::WarpedThing> <- L<Config::Model::AnyThing> 

=item *

L<Config::Model::CheckList> <- L<Config::Model::ListId> <- L<Config::Model::WarpedThing> <- L<Config::Model::AnyThing> 

=item *

L<Config::Model::WarpedNode> <- <- L<Config::Model::WarpedThing> <- L<Config::Model::AnyThing> 


=back


=head2 Model utilities

L<Config::Model::Describe>,
L<Config::Model::Dumper>,
L<Config::Model::Loader>,
L<Config::Model::ObjTreeScanner>,
L<Config::Model::Report>,
L<Config::Model::Searcher>,
L<Config::Model::TermUI>,
L<Config::Model::WizardHelper>,

=cut
