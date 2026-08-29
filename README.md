# HelpMe — macOS e iPadOS

App per docenti di sostegno dell'I.I.S. "Antonio Della Lucia" di Feltre.
Trasforma un testo curricolare nel materiale didattico personalizzato che
serve a un alunno con DSA o ADHD, secondo il D.I. 182/2020.

Progetto Xcode (`Helpme.xcodeproj`), SwiftUI, macOS 14+ / iPadOS 17+.
**258 test.**

## Cosa fa

**Per il docente** — genera sette formati di materiale (verifica
equipollente, formulario, scheda PDP, mappa concettuale, glossario,
spiegazione semplificata, quiz di autoverifica), con un indice documentale
che l'IA può consultare: si importano PDF, Word, EPUB, RTF e testo.
L'esportazione produce un documento Word con l'intestazione istituzionale,
le tabelle e la griglia di valutazione vere.

**Per lo studente** — lettura ad alta voce con evidenziazione karaoke,
righello di lettura, sillabazione a colori alternati, font Lexend e
OpenDyslexic, quattro temi anti-affaticamento. La mappa concettuale si
naviga e il quiz si fa davvero, con il riscontro dopo ogni risposta. Il
timer Focus propone pause attive e tiene i traguardi.

## Le quattro regole che reggono il progetto

**I dati dei minori restano sul dispositivo.** L'app tratta dati personali
e sanitari di minori con disabilità. Verso il cloud esce solo la forma
pseudonimizzata: nome e riferimenti diagnostici non lasciano il Mac, e il
nome rientra soltanto in locale nella risposta. `StudentPseudonymizer` è
quel confine, e `PrivacyTests` lo presidia — se un cambiamento fa fallire
quei test non è un test da aggiustare, è una fuga da fermare.

**Lo studente non deve vedere le risposte.** Il materiale che gli arriva —
a schermo, letto ad alta voce o stampato — passa da `StudyTextPresenter`,
che toglie i marcatori della risposta esatta. Nel documento Word la chiave
di correzione finisce in coda, dopo un'interruzione di pagina: il docente
ce l'ha e gli basta non stampare l'ultima pagina.

**La chiave API la mette solo l'amministratore.** Nessun docente deve
doverla inserire: il pannello è protetto da una password amministratore
(PBKDF2, nessun segreto nel sorgente). Protegge dalle modifiche accidentali,
non da chi è amministratore della macchina — non è spacciato per di più.

**Una licenza scaduta ferma la generazione, mai la lettura.** Il materiale
già prodotto è dello studente che lo sta usando: nessuna questione
amministrativa deve fargli trovare lo schermo bloccato a metà di una scheda.
Chi deve rinnovare è la scuola, e la scuola lo dice al docente, non all'alunno.
`LicenseGate.canRead` restituisce sempre vero, ed è una funzione e non una
costante sottintesa proprio perché un test possa presidiarla.

## Compilare

Da Xcode, oppure da VS Code con i task già configurati (⇧⌘B):

```bash
xcodebuild -project Helpme.xcodeproj -scheme Helpme -destination 'platform=macOS' test
```

Per l'interfaccia conviene comunque Xcode: le anteprime SwiftUI e
l'ispettore di accessibilità, su un'app per studenti con DSA, servono.

## Motore IA

Usa il modello integrato nel Mac (Apple Intelligence) quando c'è — nessuna
chiave, nessun dato fuori — e ricade su Google Gemini altrimenti. La scelta
è automatica per formato: i documenti lunghi e strutturati vanno al cloud,
il resto sta bene al modello locale. Il docente può forzarla.

## Distribuzione e licenze

```bash
Tools/distribuisci.sh --controlla
```

Dice cosa manca per poter consegnare l'app. Oggi mancano il certificato
Developer ID e le credenziali di notarizzazione: entrambi richiedono
l'iscrizione all'Apple Developer Program. Senza, l'app resta firmata "Apple
Development" e si apre solo sui Mac registrati nell'account di chi la
compila — sul portatile di un collega macOS non la avvia affatto.

Le licenze sono foglietti firmati ECDSA P-256 e si verificano **senza rete**: su
una rete scolastica un controllo online sarebbe un punto di rottura in più, e
contraddirebbe la promessa che l'app non parla con nessuno se non glielo si
chiede. `Tools/licenza.swift` genera la coppia di chiavi dell'emittente ed
emette le licenze; la chiave privata non sta in questo repository e non deve
starci mai. Finché `LicenseVerifier.issuerPublicKey` è vuota, l'app non
applica nessuna licenza: meglio una copia di sviluppo che funziona di una che
si blocca da sola.

La curva è P-256 e non Ed25519 perché la stessa licenza deve valere sul Mac
e sul PC di una scuola che ne compra una: .NET 8, su cui gira la controparte
Windows, non espone Ed25519, e implementarlo là vorrebbe dire aggiungere una
libreria di crittografia di terze parti. P-256 è di prima parte su entrambi,
e l'interoperabilità è stata verificata firmando qui e verificando in .NET.

Non c'è revoca. Una licenza emessa vale fino alla sua scadenza, perché una
verifica offline non può sapere che è stata ritirata.

## Controparte Windows

[`HelpMe-windows`](https://github.com/makiumjs/HelpMe-windows) — riscrittura
in WinUI 3 allo stesso stadio di funzionalità. Questa versione Swift è il
riferimento quando un comportamento di là è ambiguo.
