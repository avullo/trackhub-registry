=head1 LICENSE

Copyright [2015-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the Trackhub Registry help desk
at C<< <http://www.trackhubregistry.org/help> >>

Questions may also be sent to the public Trackhub Registry list at
C<< <https://listserver.ebi.ac.uk/mailman/listinfo/thregistry-announce> >>

=head1 NAME

Registry::TrackHub - Represents a top-level track hub container

=head1 SYNOPSIS

  my $th = Registry::TrackHub->new(url => $URL, permissive => 1);

  # print some basic hub info
  print "Hub name: ", $th->hub;
  print "Hub email: ", $th->email;

  # the list of assemblies in the hub
  print @{$th->assemblies}, "\n";

  # get specific assembly information
  my $genome = $th->get_genome("hg38");

=head1 DESCRIPTION

A class which represents information contained in a UCSC-style track hub.

=head1 AUTHOR

Alessandro Vullo, C<< <avullo at ebi.ac.uk> >>

=head1 BUGS

No known bugs at the moment. Development in progress.

=cut

package Registry::TrackHub;

use strict;
use warnings;

use Registry::TrackHub::Genome;
use Registry::Utils qw(run_cmd);
use Registry::Utils::URL qw(read_file);
use Encode qw(decode_utf8 FB_CROAK);

use vars qw($AUTOLOAD);

=head1 METHODS

=cut

sub AUTOLOAD {
  my $self = shift;
  my $attr = $AUTOLOAD;
  $attr =~ s/.*:://;

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods

  $self->{$attr} = shift if @_;

  return $self->{$attr};
}

=head2 new

  Arg [url]        : string (required)
                     The hub URL
  Arg [permissive] : boolean (optional)
                     Whether or not to validate the hub using hubCheck (UCSC)
  Example          : my $URL = "ftp://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub";
                     my $th = Registry::TrackHub->new(url => $URL, permissive => 1);
  Description      : Build a new TrackHub object 
  Returntype       : Registry::TrackHub
  Exceptions       : Throws if required parameters are not specified or if hub at specified URL does not
                     pass hubCheck validation (when permissive is false)
  Caller           : general
  Status           : stable

=cut

sub new {
  my ($class, %args) = @_;

  defined $args{url} or die "Undefined URL parameter.";

  my $self = \%args;
  bless $self, $class;

  # check hub is compliant to UCSC specs
  # use hubCheck program to check a track data hub for integrity
  $self->_hub_check() unless $self->{permissive};

  # fetch hub info
  $self->_get_hub_info();

  return $self;
}

=head2 assemblies

  Arg [1]     : none
  Example     : print @{$th->assemblies}, "\n";
  Description : Returns a list of assembly names for which the hub provides data
  Returntype  : array
  Exceptions  : none
  Caller      : general
  Status      : stable

=cut

sub assemblies {
  my $self = shift;
  
  return keys %{$self->genomes};
}

=head2 get_genome

  Arg [1]     : string - the name of the assembly as specified in the hub genomes file
  Example     : my $genome = $th->get_genome("hg38");
  Description : Returns an object containing information for a genome assembly as
                specified in the hub genomes file.
  Returntype  : Registry::TrackHub::Genome
  Exceptions  : none
  Caller      : general
  Status      : stable

=cut

sub get_genome {
  my ($self, $assembly) = @_;
  defined $assembly or die "Cannot get genome data: undefined assembly argument";

  exists $self->genomes->{$assembly} or
    die "No genome data for assembly $assembly";

  return $self->genomes->{$assembly};
}

# TODO: finish check
sub _hub_check {
  my $self = shift;
  my $url = $self->url;

  my @split_url = split '/', $url;
  my $hub_file;
  
  if ($split_url[-1] =~ /[.?]/) {
    $hub_file = pop @split_url;
    $url      = join '/', @split_url;
  } else {
    $hub_file = 'hub.txt';
    $url      =~ s|/$||;
  }

  my $cmd = sprintf("hubCheck -checkSettings -test -noTracks %s/%s", $url, $hub_file);
  my ($rc, $output) = Registry::Utils::run_cmd($cmd);
  if ($output =~ /problem/) {
    my @lines = split /\n/, $output;
    shift @lines;
    for my $line (@lines) {
      # Raise exception as soon as we detect some problem
      # which is not related to some deprecated feature
      next if $line =~ /deprecated/;

      die "hubCheck report:\n$output\n\nPlease refer to the (versioned) spec document: http://genome-test.cse.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html";
    }
  }
}

sub _get_hub_info {
  my $self = shift;
  my $url = $self->url;

  my @split_url = split '/', $url;
  my $hub_file;
  
  if ($split_url[-1] =~ /[.?]/) {
    $hub_file = pop @split_url;
    $url      = join '/', @split_url;
  } else {
    $hub_file = 'hub.txt';
    $url      =~ s|/$||;
  }

  my $file_args = { nice => 1 };
  my $response = read_file("$url/$hub_file", $file_args);
  my $content;
 
  if ($response->{error}) {
    push @{$response->{error}}, "Please check the source URL in a web browser.";
    die join("\n", @{$response->{error}});
  }
  $content = Encode::decode_utf8($response->{'content'}, Encode::FB_CROAK);

  my %hub_details;

  ## Get file name for file with genome info
  foreach (split /\n/, $content) {
    my @line = split /\s/, $_, 2;
    $line[1] =~ s/^\s+|\s+$//g; # trim left/right spaces
    $hub_details{$line[0]} = $line[1];
  }
  die 'No genomesFile found' unless $hub_details{genomesFile};
 
  ## Now get genomes file and parse 
  $response = read_file("$url/$hub_details{'genomesFile'}", $file_args); 
  die join("\n", @{$response->{error}}) if $response->{error};
  
  $content = $response->{content};

  (my $genome_file = $content) =~ s/\r//g;
  my $genomes;
  my @lines = split /\n/, $genome_file;
  my ($genome, $file, %ok_genomes);
  foreach (split /\n/, $genome_file) {
    my ($k, $v) = split(/\s/, $_);
    next unless $k =~ /^\w/;

    if ($k =~ /genome/) {
      $genome = $v;
      $genomes->{$genome} = Registry::TrackHub::Genome->new(assembly => $genome);
      ## Check if any of these genomes are available on this site,
      ## because we don't want to waste time parsing them if not!
      # if ($assembly_lookup && $assembly_lookup->{$genome}) {
      #  $ok_genomes{$genome} = 1;
      # }
      # else {
      #  $genome = undef;
      # }
    } else {
      $genomes->{$genome}->$k($v);
    }
  }

  ## Parse list of config files
  my @errors;

  foreach my $genome (keys %{$genomes}) {
    $file = $genomes->{$genome}->trackDb;
 
    if ($file =~ /^http|^ftp/) { # path to trackDB could be remote
      $response = read_file("$file", $file_args);
    } else {
      $response = read_file("$url/$file", $file_args);  
    }
    push @errors, "$genome ($url/$file): " . @{$response->{error}}
      if $response->{error};
    $content = $response->{content};
    
    my @track_list;
    $content =~ s/\r//g;
    
    # Hack here: Assume if file contains one include it only contains includes and no actual data
    # Would be better to resolve all includes (read the files) and pass the complete config data into 
    # the parsing function rather than the list of file names
    foreach (split /\n/, $content) {
      next if /^#/ || !/\w+/ || !/^include/;
      
      s/^include //;
      push @track_list, "$url/$_";
    }
    
    if (scalar @track_list) {
      ## replace trackDb file location with list of track files
      $genomes->{$genome}->trackDb(\@track_list);
    } else {
      if ($file =~ /^http|^ftp/) {
	$genomes->{$genome}->trackDb([ "$file" ]);	
      } else {
	$genomes->{$genome}->trackDb([ "$url/$file" ]);	
      }
    }
  }

  die join("\n", @errors) if scalar @errors;

  map { $self->$_($hub_details{$_}) } keys %hub_details;
  $self->genomes($genomes);

  return;
}

1;
