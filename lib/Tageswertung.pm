# Tageswertung

# Copyright 2012-2014  Andreas Gruenbacher  <andreas.gruenbacher@gmail.com>
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

package Tageswertung;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(tageswertung);

use utf8;
use List::Util qw(max);
use POSIX qw(modf);
use RenderOutput;
use Auswertung;
use Berechnung;
use Wertungen;
use strict;

sub rang_wenn_definiert($$) {
    my ($a, $b) = @_;

    return exists($b->{rang}) - exists($a->{rang})
	if !exists($a->{rang}) || !exists($b->{rang});
    return defined($b->{rang}) - defined($a->{rang})
	if !defined($a->{rang}) || !defined($b->{rang});
    return $a->{rang} <=> $b->{rang}
	if $a->{rang} != $b->{rang};
    return $a->{startnummer} <=> $b->{startnummer};
}

sub punkte_pro_sektion($$$) {
    my ($fahrer, $runde, $cfg) = @_;
    my $punkte_pro_sektion;

    my $klasse = $fahrer->{wertungsklasse};
    my $punkte_pro_runde = $fahrer->{punkte_pro_sektion}[$runde];
    my $auslassen = $cfg->{punkte_sektion_auslassen};
    foreach my $sektion (@{$cfg->{sektionen}[$klasse - 1]}) {
	my $p = $punkte_pro_runde->[$sektion - 1];
	push @$punkte_pro_sektion, defined $p ? ($p == -1 ? $auslassen : $p) : '-';
    }
    return join(" ", @$punkte_pro_sektion);
}

sub klassenstatistik($$$$) {
    my ($fahrer_in_klasse, $fahrer_gesamt, $ausfall, $cfg) = @_;

    foreach my $fahrer (@$fahrer_in_klasse) {
	if ($fahrer->{start}) {
	    $$fahrer_gesamt++;
	    $ausfall->{$fahrer->{ausfall}}++;
	    $ausfall->{ausser_konkurrenz}++
		if ausser_konkurrenz($fahrer, $cfg);
	}
    }
}

sub fahrerstatistik($$$) {
    my ($fahrer_nach_klassen, $klasse, $cfg) = @_;

    my $fahrer_gesamt = 0;
    my $ausfall = {};

    if (defined $klasse) {
	my $fahrer_in_klasse = $fahrer_nach_klassen->{$klasse};
	klassenstatistik $fahrer_in_klasse, \$fahrer_gesamt, $ausfall, $cfg;
   } else {
	foreach my $klasse (keys %$fahrer_nach_klassen) {
	    my $fahrer_in_klasse = $fahrer_nach_klassen->{$klasse};
	    klassenstatistik $fahrer_in_klasse, \$fahrer_gesamt, $ausfall, $cfg;
	}
    }

    my @details;
    push @details, (($ausfall->{5} // 0) + ($ausfall->{6} // 0)) .
		   " nicht gestartet"
	if $ausfall->{5} || $ausfall->{6};
    push @details, "$ausfall->{3} ausgefallen"
	if $ausfall->{3};
    push @details, "$ausfall->{4} nicht gewertet"
	if $ausfall->{4};
    push @details, "$ausfall->{ausser_konkurrenz} außer Konkurrenz"
	if $ausfall->{ausser_konkurrenz};
    return ($fahrer_gesamt || 'Keine') . " Fahrer" .
	(@details ? " (davon " . join(", ", @details) . ")" : "") . ".";
}

sub punkte_in_runde($) {
    my ($runde) = @_;

    if (defined $runde) {
	foreach my $punkte (@$runde) {
	    return 1 if defined $punkte;
	}
    }
    return "";
}

sub tageswertung(@) {
  # cfg fahrer_nach_startnummer wertung spalten klassenfarben alle_punkte
  # nach_relevanz klassen statistik_pro_klasse statistik_gesamt
    my %args = (
	klassenfarben => $Auswertung::klassenfarben,
	@_,
    );
    my $features = $args{features};

    my $ausfall = {
	3 => "ausgefallen",
	4 => "nicht gewertet",
	5 => "nicht gestartet",
	6 => "nicht gestartet, entschuldigt"
    };

    wertungsklassen_setzen $args{fahrer_nach_startnummer}, $args{cfg};

    # Nur bestimmte Klassen anzeigen?
    if ($args{klassen}) {
	my $klassen = { map { $_ => 1 } @{$args{klassen}} };
	foreach my $startnummer (keys %{$args{fahrer_nach_startnummer}}) {
	    my $fahrer = $args{fahrer_nach_startnummer}{$startnummer};
	    delete $args{fahrer_nach_startnummer}{$startnummer}
		unless exists $klassen->{$fahrer->{wertungsklasse}};
	}
    }

    my $zusatzpunkte;
    my $vierpunktewertung = $args{cfg}{vierpunktewertung} ? 1 : 0;
    foreach my $fahrer (values %{$args{fahrer_nach_startnummer}}) {
	$zusatzpunkte = 1
	    if $fahrer->{zusatzpunkte};
    }

    my $klassen = $args{cfg}{klassen};
    my $klassen_vergleich = sub ($$) {
	my ($a, $b) = @_;
	return $klassen->[$a - 1]{reihenfolge} <=> $klassen->[$b - 1]{reihenfolge};
    };

    my $fahrer_nach_klassen = fahrer_nach_klassen($args{fahrer_nach_startnummer});
    doc_p fahrerstatistik($fahrer_nach_klassen, undef, $args{cfg})
	if $args{statistik_gesamt};
    foreach my $klasse (sort $klassen_vergleich keys %$fahrer_nach_klassen) {
	my $fahrer_in_klasse = $fahrer_nach_klassen->{$klasse};
	my $runden = $klassen->[$klasse - 1]{runden};
	my ($header, $body, $format);
	my $farbe = "";

	$fahrer_in_klasse = [
	    map { $_->{start} ? $_ : () } @$fahrer_in_klasse ];
	next unless @$fahrer_in_klasse > 0;

	my $stechen = 0;
	foreach my $fahrer (@$fahrer_in_klasse) {
	    $stechen = 1
	       if $fahrer->{stechen};
	}

	my $wertungspunkte;
	foreach my $fahrer (@$fahrer_in_klasse) {
	    $wertungspunkte = 1
		if defined $fahrer->{wertungen}[$args{wertung} - 1]{punkte};
	}

	my $ausfall_fmt = "c" . (1 + ($features->{einzelpunkte} ?
				        0 :
					4 + $vierpunktewertung + exists($features->{spalte5er}) + $stechen));

	if ($RenderOutput::html && exists $args{klassenfarben}{$klasse}) {
	    $farbe = "<span style=\"display:block; width:10pt; height:10pt; background-color:$args{klassenfarben}{$klasse}\"></span>";
	}

	print "\n<div class=\"klasse\" id=\"klasse$klasse\">\n"
	    if $RenderOutput::html;
	doc_h3 "$klassen->[$klasse - 1]{bezeichnung}";
	push @$format, "r3", "r3", "l";
	push @$header, [ "$farbe", "c" ];
	push @$header, [ "Nr.", "r1", "title=\"Startnummer\"" ]
		if $features->{startnummer};
	push @$header, [ "Name", "l"];
	foreach my $spalte (@{$args{spalten}}) {
	    push @$format, "l";
	    push @$header, spaltentitel($spalte);
	}
	for (my $n = 0; $n < $runden; $n++) {
	    if ($features->{einzelpunkte}) {
		foreach my $sektion (@{$args{cfg}{sektionen}[$klasse - 1]}) {
		    push @$format, "r2";
		    push @$header, [ $sektion, "r1", "style=\"width:1.2em\" title=\"Sektion $sektion\"" ];
		}
	    }
	    if ($runden > 1) {
		push @$format, "r2";
		push @$header, [ "R" . ($n + 1), "r1", "title=\"Runde " . ($n + 1) . "\"" ];
	    }
	}
	if ($zusatzpunkte) {
	    push @$format, "r2";
	    push @$header, [ "ZP", "r1", "title=\"Zeit- und Zusatzpunkte\"" ];
	}
	push @$format, "r3";
	push @$header, [ "Ges", "r1", "title=\"Gesamtpunkte\"" ];
	unless ($features->{einzelpunkte}) {
	    push @$format, "r2", "r2", "r2", "r2";
	    push @$header, [ "0S", "r1", "title=\"Nuller\"" ];
	    push @$header, [ "1S", "r1", "title=\"Einser\"" ];
	    push @$header, [ "2S", "r1", "title=\"Zweier\"" ];
	    push @$header, [ "3S", "r1", "title=\"Dreier\"" ];
	    if ($vierpunktewertung) {
		push @$format, "r2";
		push @$header, [ "4S", "r1", "title=\"Vierer\"" ];
	    }
	    if ($features->{spalte5er}) {
		push @$format, "r2";
		push @$header, [ "5S", "r1", "title=\"Fünfer\"" ];
	    }
	}
	if ($stechen) {
	    push @$format, "r2";
	    push @$header, [ "ST", "r1", "title=\"Stechen\"" ];
	}
	push @$format, "r2";
	push @$header, [ "WP", "r1", "title=\"Wertungspunkte\"" ]
	    if $wertungspunkte;

	$fahrer_in_klasse = [ sort rang_wenn_definiert @$fahrer_in_klasse ];

	if ($args{nach_relevanz} && $RenderOutput::html) {
	    # Welche 0er, 1er, ... sind für den Rang relevant?
	    for (my $n = 0; $n < @$fahrer_in_klasse - 1; $n++) {
		my $a = $fahrer_in_klasse->[$n];
		my $b = $fahrer_in_klasse->[$n + 1];

		next
		    unless defined $a->{punkte} && defined $b->{punkte};

		if ($a->{punkte} == $b->{punkte} &&
		    !$a->{stechen} && !$b->{stechen}) {
		    my $m;

		    for ($m = 0; $m < 5; $m++) {
			if ($a->{punkteverteilung}[$m] != $b->{punkteverteilung}[$m]) {
			    $a->{punkteverteilung_wichtig}[$m] = 1;
			    $b->{punkteverteilung_wichtig}[$m] = 1;
			    last;
			}
		    }

		    if ($m == 5) {
			my $ra = $a->{punkte_pro_runde};
			my $rb = $b->{punkte_pro_runde};

			if ($args{cfg}{wertungsmodus} == 1) {
			    for (my $m = 0; $m < $runden; $m++) {
				if ($ra->[$m] != $rb->[$m]) {
				    $a->{runde_wichtig}[$m] = 1;
				    $b->{runde_wichtig}[$m] = 1;
				    last;
				}
			    }
			} elsif ($args{cfg}{wertungsmodus} == 2) {
			    for (my $m = $runden - 1; $m >= 0; $m--) {
				if ($ra->[$m] != $rb->[$m]) {
				    $a->{runde_wichtig}[$m] = 1;
				    $b->{runde_wichtig}[$m] = 1;
				    last;
				}
			    }
			}
		    }
		}
	    }
	}

	foreach my $fahrer (@$fahrer_in_klasse) {
	    my $row;
	    if (!(ausser_konkurrenz($fahrer, $args{cfg}) || $fahrer->{ausfall})) {
		my $rang = $fahrer->{rang};
		push @$row, defined $rang ? "$fahrer->{rang}." : "";
	    } else {
		push @$row, "";
	    }
	    my $startnummer = $fahrer->{startnummer};
	    push @$row, $startnummer < 0 ? undef : $startnummer
		if $features->{startnummer};
	    push @$row, [ $fahrer->{nachname} . " " . $fahrer->{vorname}, 'l', 'style="padding-right:1em"' ];
	    foreach my $spalte (@{$args{spalten}}) {
		push @$row, spaltenwert($spalte, $fahrer);
	    }
	    for (my $n = 0; $n < $runden; $n++) {
		if ($features->{einzelpunkte}) {
		    my $punkte_pro_runde = $fahrer->{punkte_pro_sektion}[$n];

		    foreach my $sektion (@{$args{cfg}{sektionen}[$klasse - 1]}) {
			my $p = $punkte_pro_runde->[$sektion - 1];
			$p = '-'
			    if !defined $p && $fahrer->{ausfall} != 0;
			push @$row, [ $p, "r1", "class=\"info\"" ];
		    }
		}

		if ($runden > 1) {
		    my $punkte;
		    my $fmt;
		    my $class;

		    if (punkte_in_runde($fahrer->{punkte_pro_sektion}[$n])) {
			$punkte = $fahrer->{punkte_pro_runde}[$n] // "-";
			if ($n >= $fahrer->{runden} && $RenderOutput::html) {
			    push @$class, "incomplete";
			}
			if ($args{alle_punkte}) {
			    my $punkte_pro_sektion = punkte_pro_sektion($fahrer, $n, $args{cfg});
			    push @$fmt, "title=\"$punkte_pro_sektion\"";
			}
		    } elsif ($fahrer->{ausfall}) {
			$punkte = "-";
		    }

		    if ($fahrer->{ausfall} != 0 || !$fahrer->{runde_wichtig}[$n]) {
			push @$class, "info";
		    } else {
			push @$class, "info2";
		    }

		    push @$fmt, "class=\"" . join(" ", @$class) . "\""
			if $class;
		    if ($fmt) {
			push @$row, [ $punkte, "r1", join(" ", @$fmt) ];
		    } else {
			push @$row, $punkte;
		    }
		}
	    }
	    push @$row, $fahrer->{zusatzpunkte} || ""
		if $zusatzpunkte;

	    if (ausser_konkurrenz($fahrer, $args{cfg}) ||
		$fahrer->{ausfall} || ($fahrer->{runden} // 0) == 0) {
		my @details = ();
		push @details, "außer konkurrenz"
		    if ausser_konkurrenz($fahrer, $args{cfg});
		push @details, $ausfall->{$fahrer->{ausfall}}
		    if $fahrer->{ausfall};
		push @$row, [ join(", ", @details), $ausfall_fmt ];
	    } else {
		push @$row, $fahrer->{punkte} // "";
		unless ($features->{einzelpunkte}) {
		    for (my $n = 0; $n < 4 + $vierpunktewertung; $n++) {
			if ($fahrer->{punkteverteilung_wichtig}[$n]) {
			    push @$row, [ $fahrer->{punkteverteilung}[$n], "r", "class=\"info2\"" ];
			} else {
			    push @$row, [ $fahrer->{punkteverteilung}[$n], "r", "class=\"info\"" ];
			}
		    }
		    if ($features->{spalte5er}) {
			if ($fahrer->{punkteverteilung_wichtig}[5]) {
			    push @$row, [ $fahrer->{punkteverteilung}[5], "r", "class=\"info2\"" ];
			} else {
			    push @$row, [ $fahrer->{punkteverteilung}[5], "r", "class=\"info\"" ];
			}
		    }
		}
		if ($stechen) {
		    my $x = $fahrer->{stechen} ? "$fahrer->{stechen}." : undef;
		    $x = [ $x, "r1", "class=\"info2\"" ]
			if $x && $args{nach_relevanz};
		    push @$row, $x;
		}
	    }

	    push @$row, wertungspunkte($fahrer->{wertungen}[$args{wertung} - 1]{punkte},
				       $args{cfg}{punkteteilung})
		if $wertungspunkte;
	    push @$body, $row;
	}
	doc_table header => $header, body => $body, format => $format;
	doc_p fahrerstatistik($fahrer_nach_klassen, $klasse, $args{cfg})
	    if $args{statistik_pro_klasse};
	print "</div>\n"
	    if $RenderOutput::html;
    }
}

1;
