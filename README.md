# HelpMe — macOS e iPadOS

App per docenti di sostegno dell'I.I.S. "Antonio Della Lucia" di Feltre.
Trasforma un testo curricolare nel materiale didattico personalizzato che
serve a un alunno con DSA o ADHD, secondo il D.I. 182/2020.

Progetto Xcode (`Helpme.xcodeproj`), SwiftUI, macOS 14+ / iPadOS 17+.
**238 test.**

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

## Le tre regole che reggono il progetto

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

## Controparte Windows

[`HelpMe-windows`](https://github.com/makiumjs/HelpMe-windows) — riscrittura
in WinUI 3 allo stesso stadio di funzionalità. Questa versione Swift è il
riferimento quando un comportamento di là è ambiguo.
