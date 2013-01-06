#! /usr/bin/perl -w -I../../trial-toolkit

# Copyright (C) 2012  Andreas Gruenbacher  <andreas.gruenbacher@gmail.com>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more
# details.
#
# You can find a copy of the GNU Affero General Public License at
# <http://www.gnu.org/licenses/>.

use utf8;
use CGI;
#use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use DBI;
use RenderOutput;
use Datenbank;
use TrialToolkit;
use strict;

binmode STDOUT, ':encoding(utf8)';
$RenderOutput::html = 1;

my $dbh = DBI->connect("DBI:$database", $username, $password, { db_utf8($database) })
    or die "Could not connect to database: $DBI::errstr\n";

my $q = CGI->new;
my $vareihe = $q->param('vareihe');
my $id = $q->param('id'); # veranstaltung
my $nach_sektionen = defined $q->param('nach_sektionen');
my $verteilung = 1;
my $verteilung_hoehe = 10;
my $verteilung_breite = 200;
my $cfg;

sub x($) {
    my ($punkte) = @_;

    my @x = (0, 0, 0, 0, 0, 0);
    my $y = 0;
    foreach my $p (@$punkte) {
	$x[$p]++;
	$y += $p;
    }
    my $n;
    if (@$punkte) {
	$n = 1 / @$punkte;
    } else {
	$n = 0;
    }

    my @rest;
    if ($verteilung) {
	my $code = "";
	my $summe = 0;
	for (my $n = 0, $summe = 0; $n < @x; $n++) {
	    $summe += $x[$n];
	}
	if ($summe) {
		for (my $n = 0, my $s = 0; $n < @x; $n++) {
		    next unless $x[$n];
		    my $w = int(($s + $x[$n]) * $verteilung_breite / $summe) -
			    int($s * $verteilung_breite / $summe);
		    $s += $x[$n];
		    $code .= "<img src=\"$n.png\" title=\"$n\" height=\"$verteilung_hoehe\" width=\"$w\" />";
		}
	}
	push @rest, [ $code, "l" ];
    }

    return ($x[0], $x[1], $x[2], $x[3],
	    ($cfg->{vierpunktewertung} ? $x[4] : ()), $x[5],
	    sprintf("%.1f", $y * $n), @rest);
}

sub verteilung_legende() {
    my @kategorien;

    for (my $n = 0; $n <= 5; $n++) {
	next if $n == 4 && !$cfg->{vierpunktewertung};
	push @kategorien, "<img src=\"$n.png\" height=\"$verteilung_hoehe\" " .
			  "width=\"$verteilung_hoehe\" /> $n";
    }
    print "<p>\n" . join(" &nbsp;\n", @kategorien) . "</p>\n";
}

my $wertung = 1;
my $klassen;
my $sth;

print "Content-type: text/html; charset=utf-8\n\n";

unless (defined $id) {
    #doc_h2 "Punktestatistiken";
    if ($vareihe) {
	$sth = $dbh->prepare(q{
	    SELECT id, titel
	    FROM vareihe_veranstaltung
	    JOIN veranstaltung USING (id)
	    JOIN wertung USING (id)
	    WHERE vareihe = ? AND wertung = ?
	    ORDER BY datum
	});
	$sth->execute($vareihe, $wertung);
    } else {
	$sth = $dbh->prepare(q{
	    SELECT id, titel
	    FROM veranstaltung
	    JOIN wertung USING (id)
	    WHERE wertung = ?
	    ORDER BY datum
	});
	$sth->execute($wertung);
    }
    print "<p>\n";
    while (my @row = $sth->fetchrow_array) {
	my ($id, $titel) = @row;
	print "<a href=\"statistik.shtml?id=$id\">$titel</a><br>\n";
    }
    print "</p>\n";
    exit;
}

$sth = $dbh->prepare(q{
    SELECT titel, vierpunktewertung
    FROM veranstaltung
    JOIN wertung USING (id)
    WHERE id = ? AND wertung = ?
});
$sth->execute($id, $wertung);
if (my @row = $sth->fetchrow_array) {
    $cfg->{titel}[$wertung - 1] = $row[0];
    $cfg->{vierpunktewertung} = $row[1];
} else {
    doc_h2 "Veranstaltung nicht gefunden.";
    exit;
}

$sth = $dbh->prepare(q{
    SELECT klasse, sektion, punkte.punkte
    FROM punkte
    JOIN fahrer USING (id, startnummer)
    WHERE id = ? AND punkte.punkte <= 5
});
$sth->execute($id);
while (my @row = $sth->fetchrow_array) {
    my ($klasse, $sektion, $punkte) = @row;
    push @{$klassen->{$klasse}{$sektion}}, $punkte;
}

$sth = $dbh->prepare(q{
    SELECT klasse, bezeichnung
    FROM klasse
    WHERE id = ?
});
$sth->execute($id);
while (my @row = $sth->fetchrow_array) {
    $cfg->{klassen}[$row[0] - 1] = $row[1];
}

if ($nach_sektionen) {
    doc_h2 "Punktestatistik – $cfg->{titel}[$wertung - 1]";
    my $format = [ qw(r3 r3 r3 r3 r3) ];
    my $header = [ qw(Sektion 0 1 2 3) ];
    if ($cfg->{vierpunktewertung}) {
	push @$format, "r3";
	push @$header, "4";
    }
    push @$format, qw(r3 r);
    push @$header, qw(5 ⌀);
    if ($verteilung) {
	push @$format, "l";
	push @$header, "";
    }
    foreach my $n (sort { $a <=> $b } keys %$klassen) {
	my $klasse = $klassen->{$n};
	my $alle_punkte;

	doc_h3 $cfg->{klassen}[$n - 1];
	my $body;
	foreach my $sektion (sort { $a <=> $b } keys %$klasse) {
	    my $punkte = $klasse->{$sektion};
	    push @$alle_punkte, @$punkte;
	    my $row;
	    push @$row, $sektion, x($punkte);
	    push @$body, $row;
	}
	my $footer = [ "", x($alle_punkte) ];
	doc_table header => $header, body => $body, footer => $footer,
		  format => $format;
    }
    verteilung_legende;
} else {
    doc_h2 "Punktestatistik – $cfg->{titel}[$wertung - 1]";
    my $format = [ qw(r3 r3 r3 r3 r3) ];
    my $header = [ qw(Klasse 0 1 2 3) ];
    if ($cfg->{vierpunktewertung}) {
	push @$format, "r3";
	push @$header, "4";
    }
    push @$format, qw(r3 r);
    push @$header, qw(5 ⌀);
    if ($verteilung) {
	push @$format, "l";
	push @$header, "";
    }
    my $body;
    my $alle_punkte;
    foreach my $n (sort { $a <=> $b } keys %$klassen) {
	my $klasse = $klassen->{$n};
	my $punkte;

	foreach my $sektion (sort { $a <=> $b } keys %$klasse) {
	    push @$punkte, @{$klasse->{$sektion}};
	}
	push @$alle_punkte, @$punkte;
	push @$body, [ $n, x($punkte) ];
    }
    my $footer = [ "", x($alle_punkte) ];
    doc_table header => $header, body => $body, footer => $footer,
	      format => $format;
    verteilung_legende;

    print "<p><a href=\"statistik.shtml?id=$id&nach_sektionen\">Nach Sektionen</a></p>\n";
}
