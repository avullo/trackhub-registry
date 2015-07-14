#
#
package Registry::TrackHub::Validator;

use strict;
use warnings;

use Capture::Tiny qw( capture );
# use Registry::Utils;

use vars qw($AUTOLOAD);

sub AUTOLOAD {
  my $self = shift;
  my $attr = $AUTOLOAD;
  $attr =~ s/.*:://;

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods

  $self->{$attr} = shift if @_;

  return $self->{$attr};
}

sub new {
  my ($class, %args) = @_;

  defined $args{schema} or die "Undefined JSON schema";
  -e $args{schema} and -f $args{schema} or
    die "Unable to read schema file: $args{schema}";

  my $self = \%args;
  bless $self, $class;

  return $self;
}

sub validate {
  my ($self, $file) = @_;

  my $cmd = sprintf("validate.py -s %s -f %s", $self->{schema}, $file);
  # my ($rc, $output) = Registry::Utils::run_cmd($cmd);
  my ($output, $err, $rc) = capture {
    system( $cmd );
  };
  
  # Handle here the unexpected, the python validation script cannot run,
  # e.g. the schema is badly formatted
  die "Cannot run command $cmd\nReturn code is $rc. Program output is:\n$output" if $rc;

  # insert here whatever condition on the output 
  # is interpreted to be a failure
  #
  # better to raise an exception, so we can emit an output
  # which indeed is interesting only if the doc does not validate
  # the caller decides what to do, stop or continue
  #
  # At the moment, the validation script simply prints the errors,
  # if there's any.
  if ($output) {
    # the validation script prepend the JSON instance
    # to the error output.
    # remove
    $output =~ s/^.+?(?=Failed.+?)//s;
    die $output;
  }

  # success
  return 1;
}

1;
