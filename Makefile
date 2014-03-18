NAME = trial-auswertung
VERSION = 0.16

CURL = curl
SED = sed

HAVE_WEASYPRINT_testing = 1

AUTH_PREFIX = $(PWD)

# Laut Dokumentation unterstützt Apache ab Version 2.3.13 eine neue Syntax für
# die Ausdrücke in SSI #if-Befehlen. Die neue Syntax ist ab Version 2.4 per
# Default aktiviert, wir verwenden aber noch die alte Syntax, die mit folgendem
# Kommando aktiviert werden muss:
#
#   SSILegacyExprParser on
#
# Der momentane Server unterstützt Option SSILegacyExprParser aber noch nicht
# und stolpert über diese Anweisung.
#
SSI_LEGACY_EXPR_PARSER_testing = 1
SSI_LEGACY_EXPR_PARSER_staging = 0
SSI_LEGACY_EXPR_PARSER_production = 0

DOWNLOAD_FILES = \
	htdocs/js/jquery.js \
	htdocs/js/jquery.min.js \
	htdocs/js/raphael.js \
	htdocs/js/raphael-min.js \
	htdocs/js/angular.js \
	htdocs/js/angular.min.js \
	htdocs/js/angular-route.js \
	htdocs/js/validate.js \

COMMON_FILES = \
	htdocs/ergebnisse.css \
	lib/Auswertung.pm.txt \
	lib/Berechnung.pm \
	lib/DatenbankAktualisieren.pm \
	lib/Datenbank.pm \
	lib/Jahreswertung.pm \
	lib/JSON_bool.pm \
	lib/Parse/Binary/FixedFormat.pm \
	lib/RenderOutput.pm \
	lib/Tageswertung.pm \
	lib/Timestamp.pm \
	lib/Trialtool.pm \
	lib/Wertungen.pm \

LOCAL_FILES = \
	db-sync.pl \
	db-export.pl \
	README \
	IO/Tee.pm \
	jahreswertung.pl \
	Makefile \
	tageswertung.pl \

GENERATED_WEB_FILES = \
	cgi-bin/api/.htaccess \
	cgi-bin/veranstalter/.htaccess \
	htdocs/admin/hilfe/.htaccess \
	htdocs/admin/.htaccess \
	htdocs/api/.htaccess \
	htdocs/ergebnisse/.htaccess \
	htdocs/.htaccess \
	htdocs/veranstalter/.htaccess \

ADMIN_FILES = \
	cgi-bin/api/api.pl \
	cgi-bin/api/.htaccess \
	cgi-bin/api/public-api.pl \
	htdocs/admin/api.js \
	htdocs/admin/directives.js \
	htdocs/admin/einstellungen/controller.js \
	htdocs/admin/einstellungen/index.html \
	htdocs/admin/hilfe/index.html \
	htdocs/admin/.htaccess \
	htdocs/admin/index.shtml \
	htdocs/admin/main/controller.js \
	htdocs/admin/main/index.html \
	htdocs/admin/nennungen/controller.js \
	htdocs/admin/nennungen/index.html \
	htdocs/admin/punkte/controller.js \
	htdocs/admin/punkte/index.html \
	htdocs/admin/sektionen/controller.js \
	htdocs/admin/sektionen/index.html \
	htdocs/admin/vareihe/controller.js \
	htdocs/admin/vareihe/index.html \
	htdocs/admin/veranstaltung/auswertung/controller.js \
	htdocs/admin/veranstaltung/auswertung/index.html \
	htdocs/admin/veranstaltung/controller.js \
	htdocs/admin/veranstaltung/index.html \
	htdocs/admin/veranstaltung/liste/controller.js \
	htdocs/admin/veranstaltung/liste/index.html \
	htdocs/api/.htaccess \

WEB_FILES = \
	$(DOWNLOAD_FILES) \
	$(GENERATED_WEB_FILES) \
	$(ADMIN_FILES) \
	cgi-bin/ergebnisse/jahreswertung-ssi.pl \
	cgi-bin/ergebnisse/statistik-ssi.pl \
	cgi-bin/ergebnisse/tageswertung-ssi.pl \
	cgi-bin/ergebnisse/vareihe-bezeichnung.pl \
	cgi-bin/ergebnisse/vareihe-ssi.pl \
	cgi-bin/pdf.pl \
	cgi-bin/veranstalter/export.pl \
	cgi-bin/veranstalter/export-ssi.pl \
	cgi-bin/veranstalter/fahrerliste.pl \
	cgi-bin/veranstalter/starterzahl-ssi.pl \
	htdocs/ergebnisse/0.png \
	htdocs/ergebnisse/1.png \
	htdocs/ergebnisse/2.png \
	htdocs/ergebnisse/3.png \
	htdocs/ergebnisse/4.png \
	htdocs/ergebnisse/5.png \
	htdocs/js/jquery.polartimer.js \
	htdocs/robots.txt \

all: testing

download: $(DOWNLOAD_FILES)

testing: download
	@$(MAKE) -s $(GENERATED_WEB_FILES) WHAT=testing

ifeq ($(SSI_LEGACY_EXPR_PARSER_$(WHAT)),1)
SSI_LEGACY_EXPR_PARSER=-e 's:^@SSI_LEGACY_EXPR_PARSER@$$:SSILegacyExprParser on:'
else
SSI_LEGACY_EXPR_PARSER=-e '/^@SSI_LEGACY_EXPR_PARSER@$$/d'
endif

generate_web_file = \
	$(SED) -e 's:@AUTH_PREFIX@:$(AUTH_PREFIX):g' \
	       -e 's:@HOST@:$(HOST):g' \
	       -e 's:@HAVE_WEASYPRINT@:$(HAVE_WEASYPRINT_$(WHAT)):g' \
	       $(SSI_LEGACY_EXPR_PARSER)

.PHONY: $(GENERATED_WEB_FILES)
$(GENERATED_WEB_FILES): %: %.in
	@$(generate_web_file) < $< > $@.tmp
	@if ! test -f "$@" || \
	    ! cmp -s "$@" "$@.tmp"; then \
	  echo "$< -> $@"; \
	  mv $@.tmp $@; \
	else \
	  rm -f $@.tmp; \
	fi

htdocs/js/jquery.js htdocs/js/jquery.min.js:
	@mkdir -p $(dir $@)
	$(CURL) -o $@ --fail --silent --location http://code.jquery.com/$(notdir $@)

htdocs/js/raphael.js htdocs/js/raphael-min.js:
	@mkdir -p $(dir $@)
	$(CURL) -o $@ --fail --silent --location \
		http://github.com/DmitryBaranovskiy/raphael/raw/master/$(notdir $@)

# AngularJS
ANGULAR_BASE=https://ajax.googleapis.com/ajax/libs/angularjs
ANGULAR_VERSION=1.2.7
htdocs/js/angular%:
	@mkdir -p  $(dir $@)
	$(CURL) -o $@ --fail --silent --location \
		$(ANGULAR_BASE)/$(ANGULAR_VERSION)/$(notdir $@)

# AngularUI Validate
htdocs/js/validate.js:
	@mkdir -p  $(dir $@)
	$(CURL) -o $@ --fail --silent --location \
		https://github.com/angular-ui/ui-utils/raw/master/modules/validate/validate.js

dist: $(COMMON_FILES) $(LOCAL_FILES)
	@set -e; \
	rm -rf $(NAME)-$(VERSION); \
	umask 022; \
	mkdir $(NAME)-$(VERSION); \
	for file in $^; do \
	    original=$$file; \
	    file=$$(echo "$$original" | $(SED) -e 's:Windows/::'); \
	    mkdir -p "$(NAME)-$(VERSION)/$$(dirname "$$file")"; \
	    case "$$file" in \
		*.pl | *.pm | *.pm.txt | README | Makefile) \
		    recode ../CR-LF < "$$original" > "$(NAME)-$(VERSION)/$$file" ;; \
		*) \
		    cat "$$original" > "$(NAME)-$(VERSION)/$$file" ;; \
	    esac; \
	    case "$$file" in \
		*.pl) \
		    chmod +x "$(NAME)-$(VERSION)/$$file" ;; \
	    esac; \
	done
	rm -f $(NAME)-$(VERSION).zip
	zip -r $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)

clean:
	rm -f $(DOWNLOAD_FILES)
