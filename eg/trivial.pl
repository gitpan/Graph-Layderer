#!/usr/bin/perl -w

use strict;
use diagnostics;
use Data::Dumper;

use lib qw (lib/);

use Graph::Undirected;
use Graph::Layouter::Spring;

use Imager;

my $g = Graph::Undirected->new();
$g->add_edges(1 => 2, 2 => 3, 4 => 5, 5 => 2);
$g->set_attribute("renderer_vertex_font", "/usr/X11/lib/X11/fonts/TTF/luxisb.ttf");
$g->set_attribute("renderer_vertex_font", 5, "/usr/X11/lib/X11/fonts/TTF/luxisr.ttf");
$g->set_attribute("renderer_vertex_font", 3, Imager::Font->new(file => "/usr/X11/lib/X11/fonts/TTF/luxisr.ttf"));
$g->set_attribute("renderer_vertex_title", 4, "FOO");
Graph::Layouter::Spring::layout($g);

use Imager;
use Graph::Renderer::Imager;

my $img = Imager->new(xsize => 800, ysize => 600, channels => 4);

my $bgcolor = Imager::Color->new(0xff, 0xff, 0xff);
$img->box(color => $bgcolor, xmin => 0, ymin => 0, xmax => 800, ymax => 600, filled => 1);

Graph::Renderer::Imager::render($g, $img);

$img->write(file=>'t.png');
