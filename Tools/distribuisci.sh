#!/bin/bash
#
# Prepara HelpMe per l'installazione sui Mac dei colleghi.
#
#   Tools/distribuisci.sh --controlla   verifica solo i prerequisiti
#   Tools/distribuisci.sh               compila, firma, notarizza, impacchetta
#
# Perche' serve: la firma "Apple Development" con cui l'app si compila ogni
# giorno vale solo sui Mac registrati nel tuo account sviluppatore. Su quello
# di un collega macOS non la apre proprio. Per distribuirla fuori dall'App
# Store servono tre cose insieme: un certificato Developer ID, il runtime
# irrobustito (gia' attivo nel progetto) e la notarizzazione, cioe' il
# passaggio in cui Apple controlla il pacchetto e rilascia una ricevuta.
#
# Prerequisiti, una volta sola:
#   1. Iscrizione all'Apple Developer Program (99 euro/anno).
#   2. Certificato "Developer ID Application" installato nel portachiavi.
#   3. Credenziali per la notarizzazione salvate nel portachiavi:
#        xcrun notarytool store-credentials "HelpMe" \
#          --apple-id "tua@email" --team-id 775T7J89BJ --password <app-specific>
#      La password non e' quella dell'ID Apple: e' una "password per app" che
#      si genera su appleid.apple.com.

set -euo pipefail

PROGETTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="Helpme"
PROFILO_NOTARIZZAZIONE="HelpMe"
TEAM_ID="775T7J89BJ"
LAVORO="$PROGETTO/build/distribuzione"

rosso() { printf '\033[31m%s\033[0m\n' "$1"; }
verde() { printf '\033[32m%s\033[0m\n' "$1"; }

mancante=0

controlla_prerequisiti() {
    echo "Controllo i prerequisiti..."
    echo

    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        verde "✓ Certificato Developer ID Application presente"
        security find-identity -v -p codesigning | grep "Developer ID Application" | sed 's/^/    /'
    else
        rosso "✗ Nessun certificato \"Developer ID Application\" nel portachiavi"
        echo "    Serve l'iscrizione all'Apple Developer Program, poi in Xcode:"
        echo "    Settings > Accounts > Manage Certificates > + > Developer ID Application"
        mancante=1
    fi
    echo

    if xcrun notarytool history --keychain-profile "$PROFILO_NOTARIZZAZIONE" >/dev/null 2>&1; then
        verde "✓ Credenziali di notarizzazione \"$PROFILO_NOTARIZZAZIONE\" funzionanti"
    else
        rosso "✗ Credenziali di notarizzazione assenti o non valide"
        echo "    xcrun notarytool store-credentials \"$PROFILO_NOTARIZZAZIONE\" \\"
        echo "      --apple-id \"tua@email\" --team-id $TEAM_ID --password <password-per-app>"
        mancante=1
    fi
    echo

    if grep -q "ENABLE_HARDENED_RUNTIME = YES" "$PROGETTO/$SCHEMA.xcodeproj/project.pbxproj"; then
        verde "✓ Runtime irrobustito attivo (obbligatorio per la notarizzazione)"
    else
        rosso "✗ Runtime irrobustito non attivo: Apple rifiuterebbe il pacchetto"
        mancante=1
    fi
    echo

    if [ "$mancante" -eq 0 ]; then
        verde "Tutto a posto: si puo' distribuire."
    else
        rosso "Manca qualcosa. Finche' e' cosi', l'app si installa solo sui Mac registrati nel tuo account."
    fi
    return "$mancante"
}

if [ "${1:-}" = "--controlla" ]; then
    controlla_prerequisiti || exit 1
    exit 0
fi

controlla_prerequisiti || {
    echo
    rosso "Non procedo: senza i prerequisiti il pacchetto non sarebbe installabile."
    exit 1
}

rm -rf "$LAVORO"
mkdir -p "$LAVORO"
ARCHIVIO="$LAVORO/HelpMe.xcarchive"
ESPORTAZIONE="$LAVORO/esportata"

echo
echo "1/5 Compilo l'archivio Release..."
xcodebuild -project "$PROGETTO/$SCHEMA.xcodeproj" \
    -scheme "$SCHEMA" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVIO" \
    archive

echo
echo "2/5 Esporto firmando con Developer ID..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVIO" \
    -exportOptionsPlist "$PROGETTO/Tools/EsportazioneDeveloperID.plist" \
    -exportPath "$ESPORTAZIONE"

APP="$ESPORTAZIONE/$SCHEMA.app"
[ -d "$APP" ] || { rosso "L'esportazione non ha prodotto $APP"; exit 1; }

echo
echo "3/5 Impacchetto per l'invio..."
ZIP="$LAVORO/HelpMe.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "4/5 Invio ad Apple per la notarizzazione (puo' richiedere qualche minuto)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILO_NOTARIZZAZIONE" --wait

echo
echo "5/5 Allego la ricevuta all'app..."
# La ricevuta va allegata all'app, non allo zip: cosi' il Mac del collega la
# trova anche senza rete, che in una scuola non e' un dettaglio.
xcrun stapler staple "$APP"

DMG="$LAVORO/HelpMe.dmg"
rm -f "$DMG"
hdiutil create -volname "HelpMe" -srcfolder "$APP" -ov -format UDZO "$DMG"
xcrun stapler staple "$DMG" || true

echo
echo "Verifica finale, come la farebbe il Mac di un collega:"
spctl -a -vvv -t install "$APP"

echo
verde "Fatto: $DMG"
echo "Questo file si puo' consegnare. Al primo avvio macOS non mostrera' avvisi."
