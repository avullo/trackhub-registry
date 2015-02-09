package Data::SearchEngine::ElasticSearch;

use Moose;

#
# ABSTRACT: Search::Elasticsearch support for Data::SearchEngine
# Adapt Data::SearchEngine::ElasticSearch to work
# with the new Search::ElasticSearch, since the original module relies
# on the deprecated ElasticSearch module
#

 
use Clone qw(clone);
use Time::HiRes;
use Try::Tiny;
use Search::Elasticsearch;
 
with (
    'Data::SearchEngine',
    'Data::SearchEngine::Modifiable'
);
 
use Data::SearchEngine::Item;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::ElasticSearch::Results;


has '_es' => (
    is => 'ro',
    isa => 'Search::Elasticsearch',
    lazy => 1,
    default => sub {
        my $self = shift;
        return Search::Elasticsearch->new(
            nodes     => $self->nodes,
            transport => $self->transport
        )
    }
);
 
has 'nodes' => (
    is => 'ro',
    isa => 'Str|ArrayRef',
    default => '127.0.0.1:9200'
);
 
has 'transport' => (
    is => 'ro',
    isa => 'Str',
    default => '+Search::Elasticsearch::Transport'
);

sub search {
  my ($self, $query, $filter_combine) = @_;
 
  unless(defined($filter_combine)) {
    $filter_combine = 'and';
  }
 
  my $options;
  if ($query->has_query) {
    die "Queries must have a type." unless $query->has_type;
    $options->{query} = { $query->type => $query->query };
  }
 
  $options->{index} = $query->index;
 
  if ($query->has_debug) {
    # Turn on explain
    $options->{explain} = 1;
  }
 
  my @facet_cache = ();
  if ($query->has_filters) {
    foreach my $filter ($query->filter_names) {
      push(@facet_cache, $query->get_filter($filter));
    }
    $options->{filter}->{$filter_combine} = \@facet_cache;
  }
 
  if ($query->has_facets) {
    # Copy filters used in the overall query into each facet, thereby
    # limiting the facets to only counting against the filtered bits.
    # This is really to replicate my expecations and the way facets are
    # usually used.
    my %facets = %{ $query->facets };
    $options->{facets} = $query->facets;
 
    if ($query->has_filters) {
      foreach my $f (keys %facets) {
	$facets{$f}->{facet_filter}->{$filter_combine} = \@facet_cache;
      }
    }
 
    # Shlep the facets into the final query, even if we didn't do anything
    # with the filters above.
    $options->{facets} = \%facets;
  }
 
  if ($query->has_order) {
    $options->{sort} = $query->order;
  }
 
  if ($query->has_fields) {
    $options->{fields} = $query->fields;
  }
 
  $options->{from} = ($query->page - 1) * $query->count;
  $options->{size} = $query->count;
 
  my $start = Time::HiRes::time;
  my $resp = $self->_es->search($options);
 
  my $page = $query->page;
  my $count = $query->count;
  my $hit_count = $resp->{hits}->{total};
  my $max_page = $hit_count / $count;
  if ($max_page != int($max_page)) {
    # If trying to calculate how many pages we _could_ have gives us a
    # non integer, add one to the page after inting it so we get the right
    # integer.
    $max_page = int($max_page) + 1;
  }
  if ($page > $max_page) {
    $page = $max_page;
  }
 
  my $pager = Data::SearchEngine::Paginator->new(
						 current_page => $page || 1,
						 entries_per_page => $count,
						 total_entries => $hit_count
						);
 
  my $result = Data::SearchEngine::ElasticSearch::Results->new(
							       query => $query,
							       pager => $pager,
							       elapsed => time - $start,
							       raw => $resp
							      );
 
  if (exists($resp->{facets})) {
    foreach my $facet (keys %{ $resp->{facets} }) {
      my $href = $resp->{facets}->{$facet};
      if (exists($href->{terms})) {
	my @vals = ();
	foreach my $term (@{ $href->{terms} }) {
	  push(@vals, { count => $term->{count}, value => $term->{term} });
	}
	$result->set_facet($facet, \@vals);
      }
    }
  }
  foreach my $doc (@{ $resp->{hits}->{hits} }) {
    my $values = $doc->{_source};
    $values->{_index} = $doc->{_index};
    $values->{_version} = $doc->{_version};
    $result->add($self->_doc_to_item($doc));
  }
 
  return $result;
}

no Moose;
__PACKAGE__->meta->make_immutable;


