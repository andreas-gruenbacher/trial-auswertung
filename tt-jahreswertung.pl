#! /usr/bin/perl -w

# Trialtool: Auswertung über mehrere Veranstaltungen machen ("Jahreswertung")

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

# TODO:
# * Filename globbing on Windows
# * Ergebnisse in Editor-Programm darstellen (wordpad?)

use open IO => ":locale";
use utf8;

use List::Util qw(max);
use Getopt::Long;
use Trialtool;
use Wertungen;
use RenderOutput;
use strict;

my $wertung = 0;  # Index von Wertung 1 (0 .. 3)
my $streichresultate = 0;

my $result = GetOptions("wertung=i" => sub { $wertung = $_[1] - 1; },
			"streich=i" => \$streichresultate,
			"html" => \$RenderOutput::html);
unless ($result) {
    print "VERWENDUNG: $0 [--wertung=(1..4)] [--streich=N]\n";
    exit 1;
}

my $veranstaltungen;

foreach my $name (trialtool_dateien @ARGV) {
    my $cfg = cfg_datei_parsen("$name.cfg");
    $cfg->{gestartete_klassen} = gestartete_klassen($cfg);
    my $fahrer_nach_startnummer = dat_datei_parsen("$name.dat");
    rang_und_wertungspunkte_berechnen $fahrer_nach_startnummer, $cfg;
    push @$veranstaltungen, [$cfg, $fahrer_nach_startnummer];
}

my $jahreswertung;
foreach my $veranstaltung (@$veranstaltungen) {
    my $fahrer_nach_startnummer = $veranstaltung->[1];

    foreach my $fahrer (values %$fahrer_nach_startnummer) {
	if (exists $fahrer->{wertungspunkte}[$wertung]) {
	    my $startnummer = $fahrer->{startnummer};
	    my $klasse = $fahrer->{klasse};
	    push @{$jahreswertung->{$klasse}{$startnummer}{wertungspunkte}},
		$fahrer->{wertungspunkte}[$wertung];
	}
    }
}

jahreswertung_berechnen $jahreswertung, $streichresultate;

sub wertung {
    return $b->{gesamtpunkte} <=> $a->{gesamtpunkte}
	if $a->{gesamtpunkte} != $b->{gesamtpunkte};
    return $a->{startnummer} <=> $b->{startnummer};
}

my ($letzte_cfg, $letzte_fahrer) =
    @{$veranstaltungen->[@$veranstaltungen - 1]};

doc_begin "Österreichischer Trialsport-Verband";
doc_h1 "Jahreswertung"; #$letzte_cfg->{wertungen}[$wertung]
if ($streichresultate) {
    if ($streichresultate == 1) {
	print "Mit 1 Streichresultat\n";
    } else {
	print "Mit $streichresultate Streichresultaten\n";
    }
}

# Wir wollen, dass alle Tabellen gleich breit sind.
my $namenlaenge = 0;
foreach my $fahrer (map { $letzte_fahrer->{$_} }
			map { keys $_ } values %$jahreswertung) {
    my $n = length "$fahrer->{nachname}, $fahrer->{vorname}";
    $namenlaenge = max($n, $namenlaenge);
}

foreach my $klasse (sort {$a <=> $b} keys %$jahreswertung) {
    my $klassenwertung = $jahreswertung->{$klasse};
    doc_h3 "$letzte_cfg->{klassen}[$klasse - 1]";
    my ($header, $body, $format);

    push @$format, "r3", "r3", "l$namenlaenge";
    push @$header, "", "Nr.", "Name";

    for (my $n = 0; $n < @$veranstaltungen; $n++) {
	my $gestartet = $veranstaltungen->[$n][0]{gestartete_klassen}[$klasse - 1];
	push @$format, "r2";
	push @$header,  $gestartet ? $n + 1 : "";
    }
    if ($streichresultate) {
	push @$format, "r3";
	push @$header, "Str";
    }
    push @$format, "r3";
    push @$header, "Ges";

    my $fahrer_in_klasse = [
	map { $letzte_fahrer->{$_->{startnummer}} }
	    (sort wertung (values %$klassenwertung)) ];

    my $letzter_fahrer;
    for (my $n = 0; $n < @$fahrer_in_klasse; $n++) {
	my $fahrer = $fahrer_in_klasse->[$n];
	my $startnummer = $fahrer->{startnummer};

	if ($letzter_fahrer &&
	    $klassenwertung->{$startnummer}{gesamtpunkte} ==
	    $klassenwertung->{$letzter_fahrer->{startnummer}}->{gesamtpunkte}) {
	    $klassenwertung->{$startnummer}{rang} =
		$klassenwertung->{$letzter_fahrer->{startnummer}}->{rang};
	} else {
	    $klassenwertung->{$startnummer}{rang} = $n + 1;
	}
	$letzter_fahrer = $fahrer;
    }

    foreach my $fahrer (@$fahrer_in_klasse) {
	my $startnummer = $fahrer->{startnummer};
	my $row;
	push @$row, "$klassenwertung->{$startnummer}{rang}.", $startnummer,
		   $fahrer->{nachname} . ", " . $fahrer->{vorname};
	for (my $n = 0; $n < @$veranstaltungen; $n++) {
	    my $veranstaltung = $veranstaltungen->[$n];
	    my $gestartet = $veranstaltung->[0]{gestartete_klassen}[$klasse - 1];
	    my $fahrer = $veranstaltung->[1]{$startnummer};
	    push @$row, ($fahrer->{klasse} = $klasse &&
			 exists($fahrer->{wertungspunkte}[$wertung])) ?
			$fahrer->{wertungspunkte}[$wertung] :
			$gestartet ? "-" : "";
	}
	push @$row, $klassenwertung->{$startnummer}{streichpunkte}
	    if $streichresultate;
	my $gesamtpunkte = $klassenwertung->{$startnummer}{gesamtpunkte};
	push @$row, $gesamtpunkte != 0 ? $gesamtpunkte : "";
	push @$body, $row;
    }
    doc_table $header, $body, $format;
}


doc_h3 "Veranstaltungen:";
my ($body, $format);
push @$format, "r3", "l";
for (my $n = 0; $n < @$veranstaltungen; $n++) {
    my $cfg = $veranstaltungen->[$n][0];

    push @$body, [ $n + 1, "$cfg->{titel}[0]: $cfg->{subtitel}[0]" ];
}
doc_table ["Nr.", "Name"], $body, $format;
doc_end;

# use Data::Dumper;
# print Dumper($cfg);
# print Dumper($fahrer_nach_startnummer);
