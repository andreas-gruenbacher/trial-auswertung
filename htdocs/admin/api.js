'use strict;'

function veranstaltungen_laden($scope, $http) {
  return $http.get('/api/veranstaltungen').
    success(function(veranstaltungen) {
      $scope.veranstaltungen = veranstaltungen;
    });
}

function features_aus_liste(veranstaltung) {
  var obj = {};
  angular.forEach(veranstaltung.features, function(feature) {
    obj[feature] = true;
  });
  obj.wertungen = [];
  for (var n = 1; n <= veranstaltung.wertungen.length; n++)
    if ('wertung' + n in obj)
      obj.wertungen.push(n);
  return obj;
}

function features_zu_liste(features) {
  var liste = [];
  angular.forEach(features, function(value, key) {
    if (key != 'wertungen' && value)
      liste.push(key);
  });
  return liste;
}

function veranstaltung_laden($scope, $http, id) {
  return $http.get('/api/veranstaltung', {'params': {'id': id}}).
    success(function(veranstaltung) {
      $scope.veranstaltung = veranstaltung;
      $scope.features = features_aus_liste(veranstaltung);
    });
}

function startende_klassen(veranstaltung) {
  var gestartet = [];
  for (var klasse = 1; klasse <= veranstaltung.klassen.length; klasse++) {
    var sektionen = veranstaltung.sektionen[klasse - 1];
    if (sektionen && sektionen.length)
      gestartet[klasse - 1] = true;
  }
  return gestartet;
}

function fahrer_laden($http, id, startnummer, richtung, fahrer) {
  var url = '/api/' + (richtung ? richtung + '/' : '') +
		      (fahrer ? fahrer : 'fahrer');
  var params = {
    'id': id,
    'startnummer': startnummer ? startnummer : '0'
  };
  return $http.get(url, {'params': params});
}

function fahrer_suchen($http, id, suchbegriff) {
  var params = {
    'id': id,
    'suchbegriff': suchbegriff.replace(/\*/g, '.*').replace(/\?/g, '.')
  };
  return $http.get('/api/fahrer/suchen', {'params': params});
}

function fahrer_speichern($http, id, startnummer, version, fahrer) {
  var params = {
    id: id,
    version: version,
    mtime: Math.trunc(new Date().getTime() / 1000)
  };
  if (startnummer !== undefined)
    params.startnummer = startnummer;
  return $http.put('/api/fahrer', fahrer, {params: params});
}

function veranstaltung_speichern($http, id, veranstaltung) {
  var params = {
    id: id,
    version: veranstaltung.version,
    mtime: Math.trunc(new Date().getTime() / 1000)
  };
  return $http.put('/api/veranstaltung', veranstaltung, {params: params});
}

function fahrer_loeschen($http, id, startnummer, version) {
  var params = {
    id: id,
    startnummer: startnummer,
    version: version
  };
  return $http.delete('/api/fahrer', {params: params});
}

function fahrer_name(fahrer, $scope) {
  var infos = [];
  if (fahrer.nachname !== null && fahrer.nachname !== '')
    infos.push(fahrer.nachname);
  if (fahrer.vorname !== null && fahrer.vorname !== '')
    infos.push(fahrer.vorname);
  if (fahrer.startnummer !== null && fahrer.startnummer >= 0)
    infos.push('(' + fahrer.startnummer + ')');
  return infos.join(' ');
}

function fahrer_infos(fahrer, $scope) {
  var infos = [];
  if (fahrer.startnummer >= 0)
    infos.push('Startnummer: ' + fahrer.startnummer);
  if (fahrer.klasse !== null)
    infos.push('Klasse: ' + fahrer.klasse);
  if (fahrer.geburtsdatum)
    infos.push('Geburtsdatum: ' +
	       $scope.$eval('fahrer.geburtsdatum | date:"d.M.yyyy"', {fahrer: fahrer}));
  return infos.join('\n');
}

function set_focus(selector, $timeout) {
  $timeout(function() {
    var element = document.querySelector(selector);
    element.focus();
    element.select();
  });
}

function beim_verlassen_warnen($scope, geaendert) {
  var daten_veraendert = 'Die Daten in diesem Formular wurden verändert.';
  window.onbeforeunload = function() {
    if (geaendert())
      return daten_veraendert;
  };
  $scope.$on('$locationChangeStart',
    function(event) {
      if (geaendert()) {
	if(!confirm(daten_veraendert + '\n\nBeim Verlassen dieser Seite gehen die Änderungen verloren.'))
	    event.preventDefault();
      }
    });
  $scope.$on('$destroy', function() {
    window.onbeforeunload = undefined;
  });
}

function veranstaltung_loeschen($http, id, version) {
  var params = {
    id: id,
    version: version
  };
  return $http.delete('/api/veranstaltung', {params: params});
}

function vareihe_speichern($http, vareihe, daten) {
  var params = {
    vareihe: vareihe,
    version: daten.version
  };
  return $http.put('/api/vareihe', daten, {params: params});
}

function vareihe_loeschen($http, vareihe, version) {
  var params = {
    vareihe: vareihe,
    version: version
  };
  return $http.delete('/api/vareihe', {params: params});
}

function http_request($q, request) {
  var deferred = $q.defer();
  request.
    success(function(data) {
      deferred.resolve(data);
    }).
    error(function(data, status) {
      deferred.reject();
      netzwerkfehler(data, status);
    });
  return deferred.promise;
}

function netzwerkfehler(data, status) {
  alert(status === 409 ?
	  'Veränderung der Daten am Server festgestellt.' :
	(status == 500 ?
	   'Interner Serverfehler.' :
	   'HTTP-Request ist ' + (status ? 'mit Status ' + status + ' ' : '') + 'fehlgeschlagen.') +
	(typeof data === 'object' && data.error !== undefined ? '\n\n' + data.error : ''));
}
