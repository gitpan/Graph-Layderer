=head1 NAME

Graph::Layouter::Spring - spring graph drawing algorithm implementation

=cut


package Graph::Layouter::Spring;

use strict;
use Carp qw (croak);

use vars qw ($VERSION @ISA @EXPORT_OK);

# $Id: Spring.pm,v 1.2 2004/04/04 00:00:07 pasky Exp $
$VERSION = 0.01;


=head1 SYNOPSIS

  use Graph::Layouter::Spring;
  Graph::Layouter::Spring::layout($graph);

=cut


use base qw (Graph::Layouter);

require Exporter;
push @ISA, 'Exporter';

@EXPORT_OK = qw (layout);


=head1 DESCRIPTION

This module provides the famous spring graph drawing algorithm implementation.
See the C<Graph::Layouter> class documentation for usage description.

=cut


use Graph;
use Graph::Base;
use Graph::Layouter;

=head2 How does it work

The algorithm is principially simple, simulating a space of electrically
charged particles. Basically, each node is thought of as a particle with the
same charge, therefore they all try to get as far of each other as possible. On
the other hand, though, there are the edges, which keep nodes together; higher
weight the edges have, stronger are they in pulling nodes near each other.

So to recapitulate, we have I<repulsive force> pushing nodes from each other
and I<attractive force> pushing connected nodes near each other. We then just
apply the repulsive force between each two nodes and the attractive force
between each two connected nodes; each node will have a resulting movement
force, which we will apply to the node's position (initially randomzero-zero)
after the forces calculation is finished.

However, we need to let this repeat for several times in order for the
positions to stabilize. In fact, a lot of iterations is needed; higher the
better, but also higher the slower, you can very easily get to tens of seconds
here so beware. Currently, the number of iterations is hardcoded to 500, but
this is expected to get configurable soon.

=cut

# TODO : _This_ should be all adjustable!

my $iterations = 1000;
my $max_repulsive_force_distance = 6;
my $k = 2;
my $c = 0.01;
my $max_vertex_movement = 0.5;

sub layout {
	my $graph = shift;

	Graph::Layouter::_layout_prepare($graph);

	# Cache
	my @vertices = $graph->vertices;

	for (my $i = 0; $i < $iterations; $i++) {
		_layout_iteration($graph, \@vertices);
	}

	Graph::Layouter::_layout_calc_bounds($graph);
}


sub _layout_repulsive($$$) {
	my ($graph, $vertex1, $vertex2) = @_;

	my $dx = $graph->get_attribute('layout_pos1', $vertex2) -
	         $graph->get_attribute('layout_pos1', $vertex1);
	my $dy = $graph->get_attribute('layout_pos2', $vertex2) -
	         $graph->get_attribute('layout_pos2', $vertex1);

	my $d2 = $dx * $dx + $dy * $dy;
	if ($d2 < 0.01) {
		$dx = rand (0.1) + 0.1;
		$dy = rand (0.1) + 0.1;
		$d2 = $dx * $dx + $dy * $dy;
	}

	my $d = sqrt $d2;
	if ($d < $max_repulsive_force_distance) {
		my $repulsive_force = $k * $k / $d;

		# Now, how simple and clear would this be without the silly
		# encapsulation games...

		$graph->set_attribute('layout_force1', $vertex2,
			$graph->get_attribute('layout_force1', $vertex2)
			+ $repulsive_force * $dx / $d);
		$graph->set_attribute('layout_force2', $vertex2,
			$graph->get_attribute('layout_force2', $vertex2)
			+ $repulsive_force * $dy / $d);

		$graph->set_attribute('layout_force1', $vertex1,
			$graph->get_attribute('layout_force1', $vertex1)
			- $repulsive_force * $dx / $d);
		$graph->set_attribute('layout_force2', $vertex1,
			$graph->get_attribute('layout_force2', $vertex1)
			- $repulsive_force * $dy / $d);
	}
}

sub _layout_attractive($$$) {
	my ($graph, $vertex1, $vertex2) = @_;

	my $dx = $graph->get_attribute('layout_pos1', $vertex2) -
	         $graph->get_attribute('layout_pos1', $vertex1);
	my $dy = $graph->get_attribute('layout_pos2', $vertex2) -
	         $graph->get_attribute('layout_pos2', $vertex1);

	my $d2 = $dx * $dx + $dy * $dy;
	if ($d2 < 0.01) {
		$dx = rand (0.1) + 0.1;
		$dy = rand (0.1) + 0.1;
		$d2 = $dx * $dx + $dy * $dy;
	}

	my $d = sqrt $d2;
	if ($d > $max_repulsive_force_distance) {
		$d = $max_repulsive_force_distance;
	}

	$d2 = $d * $d;
	my $attractive_force = ($d2 - $k * $k) / $k;
	my $weight = $graph->get_attribute('weight', $vertex1, $vertex2);
	$weight = 1 if not $weight or $weight < 1;
	$attractive_force *= log($weight) * 0.5 + 1;

	$graph->set_attribute('layout_force1', $vertex2,
		$graph->get_attribute('layout_force1', $vertex2)
		- $attractive_force * $dx / $d);
	$graph->set_attribute('layout_force2', $vertex2,
		$graph->get_attribute('layout_force2', $vertex2)
		- $attractive_force * $dy / $d);

	$graph->set_attribute('layout_force1', $vertex1,
		$graph->get_attribute('layout_force1', $vertex1)
		+ $attractive_force * $dx / $d);
	$graph->set_attribute('layout_force2', $vertex1,
		$graph->get_attribute('layout_force2', $vertex1)
		+ $attractive_force * $dy / $d);
}

sub _layout_iteration($$) {
	my ($graph, $vertices) = @_;

	# Welcome to the time-critical zone

	# Forces on vertices due to vertex-vertex repulsions

	foreach my $n1 (0 .. $#$vertices) {
		my $vertex1 = $vertices->[$n1];
		foreach my $n2 ($n1 + 1 .. $#$vertices) {
			my $vertex2 = $vertices->[$n2];

			_layout_repulsive($graph, $vertex1, $vertex2);
		}
	}

	# Forces on vertices due to edge attractions

	my @edges = $graph->edges;
	while (my ($vertex1, $vertex2) = splice (@edges, 0, 2)) {
		_layout_attractive($graph, $vertex1, $vertex2);
	}

	# Move by the given force

	foreach my $vertex (@$vertices) {
		my $xmove = $c * $graph->get_attribute('layout_force1', $vertex);
		my $ymove = $c * $graph->get_attribute('layout_force2', $vertex);

		my $max = $max_vertex_movement;
		$xmove = $max if $xmove > $max;
		$xmove = -$max if $xmove < -$max;
		$ymove = $max if $ymove > $max;
		$ymove = -$max if $ymove < -$max;

		$graph->set_attribute('layout_pos1', $vertex,
			$graph->get_attribute('layout_pos1', $vertex)
			+ $xmove);
		$graph->set_attribute('layout_pos2', $vertex,
			$graph->get_attribute('layout_pos2', $vertex)
			+ $ymove);

		$graph->set_attribute('layout_force1', $vertex, 0);
		$graph->set_attribute('layout_force2', $vertex, 0);
	}
}


=head1 SEE ALSO

C<Graph>, C<Graph::Layouter>, C<Graph::Renderer>


=head1 BUGS

The object-oriented interface is missing as well as some more universal layout
calling interface (hash parameters).

It should all be configurable.


=head1 COPYRIGHT

Copyright 2004 by Petr Baudis E<lt>pasky@ucw.czE<gt>.

This code is distributed under the same copyright terms as
Perl itself.


=head1 VERSION

Version 0.01

$Id: Spring.pm,v 1.2 2004/04/04 00:00:07 pasky Exp $

=cut

1;
