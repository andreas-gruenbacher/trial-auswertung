'use strict;'

var vareiheController = [
  '$scope', '$http', '$timeout', '$location', '$window', 'vareihe', 'veranstaltungen',
  function ($scope, $http, $timeout, $location, $window, vareihe, veranstaltungen) {
    $scope.$root.kontext(vareihe ? vareihe.bezeichnung : 'Neue Veranstaltungsreihe');

    var veranstaltungsdatum = {};
    if (veranstaltungen) {
      if (vareihe && vareihe.vareihe !== undefined) {
	angular.forEach(veranstaltungen, function(veranstaltung) {
	  veranstaltung.vareihen = veranstaltung.vareihen.filter(function(v) {
	    return v.vareihe !== vareihe.vareihe;
	  });
	});
      }

      //veranstaltungen.reverse();
      $scope.veranstaltungen = veranstaltungen;
      angular.forEach(veranstaltungen, function (veranstaltung) {
	veranstaltungsdatum[veranstaltung.id] = veranstaltung.datum;
      });
    }
    vareihe_zuweisen(vareihe);

    $scope.veranstaltung_bezeichnung = veranstaltung_bezeichnung;
    $scope.veranstaltung_sichtbar = function(veranstaltung) {
      return $scope.vareihe.abgeschlossen ||
	     !(veranstaltung.abgeschlossen || false);
    };

    function sort_uniq(array, cmp) {
      array = array.sort(cmp);
      for (var n = 0; n < array.length - 1; n++)
	if (!cmp(array[n], array[n + 1])) {
	  array.splice(n + 1, 1);
	  n--;
	}
      return array;
    }

    function cmp_null(a, b) {
      if (a === null || b === null) {
	a = (a === null);
	b = (b === null);
      }
      return a > b ? 1 : a < b ? -1 : 0;
    }

    function klassen_normalisieren(vareihe) {
      var klassen = vareihe.klassen;
      if (!klassen.length ||
	  klassen[klassen.length - 1].klasse !== null)
	klassen.push({klasse: null});
      else {
	for (var n = 0; n < klassen.length - 1; n++)
	  if (klassen[n].klasse === null)
	    klassen = klassen.splice(n, 1);
      }
      var sorted = sort_uniq(klassen, function(a, b) {
	return cmp_null(a.klasse, b.klasse);
      });
      if (!angular.equals(klassen, sorted))
	vareihe.klassen = sorted;
    }

    $scope.$watch('vareihe.klassen', function() {
      try {
	klassen_normalisieren($scope.vareihe);
      } catch (_) {}
    }, true);

    function veranstaltungen_normalisieren(vareihe) {
      var veranstaltungen = vareihe.veranstaltungen;
      if (!veranstaltungen.length ||
	  veranstaltungen[veranstaltungen.length - 1] !== null)
	veranstaltungen.push(null);
      else {
	for (var n = 0; n < veranstaltungen.length - 1; n++)
	  if (veranstaltungen[n] === null)
	    veranstaltungen.splice(n, 1);
      }
      var sorted = sort_uniq(veranstaltungen, function (a, b) {
	return cmp_null((veranstaltungsdatum[a] || '9999-99-99'),
			(veranstaltungsdatum[b] || '9999-99-99')) ||
	       cmp_null(a, b);
      });
      if (!angular.equals(veranstaltungen, sorted))
	vareihe.veranstaltungen = sorted;

      var startnummern = {};
      angular.forEach(veranstaltungen, function(id) {
	if (id == null)
	  return;
	if (vareihe.startnummern[id])
	  startnummern[id] = vareihe.startnummern[id];
	else
	  startnummern[id] = [];
      });
      vareihe.startnummern = startnummern;
    }

    $scope.$watch('vareihe.veranstaltungen', function() {
      try {
	veranstaltungen_normalisieren($scope.vareihe);
      } catch (_) {}
    }, true);

    function startnummern_normalisieren(vareihe) {
      angular.forEach(vareihe.startnummern, function(aenderungen) {
	if (!aenderungen.length ||
	    aenderungen[aenderungen.length - 1].alt !== null)
	    aenderungen.push({ alt: null, neu: null });
	else {
	  for (var n = 0; n < aenderungen.length - 1; n++)
	    if (aenderungen[n].alt == null) {
	      aenderungen.splice(n, 1);
	      n--;
	    }
	}
      });
    }

    $scope.$watch('vareihe.startnummern', function() {
      try {
	startnummern_normalisieren($scope.vareihe);
      } catch (_) {}
    }, true);

    function vareihe_zuweisen(vareihe) {
      if (vareihe === undefined)
	vareihe = $scope.vareihe_alt;
      else {
	if (vareihe === null) {
	  vareihe = {
	    version: 0,
	    bezeichnung: 'Neue Veranstaltungsreihe',
	    klassen: [],
	    veranstaltungen: [],
	    startnummern: {},
	    wertung: 1
	  };
	}
	klassen_normalisieren(vareihe);
	veranstaltungen_normalisieren(vareihe);
	startnummern_normalisieren(vareihe);
      }
      $scope.ist_neu = vareihe.vareihe === undefined;
      $scope.vareihe = vareihe;
      $scope.vareihe_alt = angular.copy(vareihe);
    }

    $scope.geaendert = function() {
      return !angular.equals($scope.vareihe_alt, $scope.vareihe);
    };

    $scope.speichern = function() {
      if ($scope.busy)
	return;
      var vareihe = angular.copy($scope.vareihe);
      var veranstaltungen = vareihe.veranstaltungen;
      if (veranstaltungen.length && veranstaltungen[veranstaltungen.length - 1] === null)
	  veranstaltungen.pop();
      var klassen = vareihe.klassen;
      if (klassen.length && klassen[klassen.length - 1].klasse === null)
	  klassen.pop();
      $scope.busy = true;
      vareihe_speichern($http, vareihe.vareihe, vareihe).
	success(function(vareihe) {
	  vareihe_zuweisen(vareihe);
	  var path = '/vareihe/' + vareihe.vareihe;
	  if ($location.path() != path) {
	    $location.path(path).replace();
	    /* FIXME: Wie Reload verhindern? */
	  }
	}).
	error(netzwerkfehler).
	finally(function() {
	  delete $scope.busy;
	});
    };

    $scope.verwerfen = function() {
      if ($scope.busy)
	return;
      vareihe_zuweisen(undefined);
    };

    $scope.loeschen = function() {
      if ($scope.busy)
	return;
      if (confirm('Veranstaltungsreihe wirklich löschen?\n\nDie Veranstaltungsreihe kann später nicht wiederhergestellt werden.')) {
	$scope.busy = true;
	vareihe_loeschen($http, $scope.vareihe.vareihe, $scope.vareihe.version).
	  success(function() {
	    $window.history.back();
	  }).
	  error(netzwerkfehler).
	  finally(function() {
	    delete $scope.busy;
	  });
      }
    };

    $scope.keydown = function(event) {
      if (event.which == 13) {
	$timeout(function() {
	  if ($scope.geaendert() && $scope.form.$valid)
	    $scope.speichern();
	});
      } else if (event.which == 27) {
	$timeout(function() {
	  if ($scope.geaendert())
	    $scope.verwerfen();
	});
      }
    };

    $scope.in_vareihe = function(veranstaltung) {
      var veranstaltungen = $scope.vareihe.veranstaltungen;
      for (var n = 0; n < veranstaltungen.length; n++)
	if (veranstaltung.id == veranstaltungen[n])
	  return true;
      return false;
    };

    beim_verlassen_warnen($scope, $scope.geaendert);
  }];

vareiheController.resolve = {
  veranstaltungen: [
    '$q', '$http', '$route',
    function($q, $http, $route) {
      return http_request($q, $http.get('/api/veranstaltungen'));
     }],
  vareihe: [
    '$q', '$http', '$route',
    function($q, $http, $route) {
      if ($route.current.params.vareihe !== undefined)
	return http_request($q, $http.get('/api/vareihe', {params: $route.current.params}));
      else
	return null;
    }]
};
