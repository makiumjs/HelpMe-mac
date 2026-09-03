# Allineamento della controparte Windows — versione senza IA

Riferimento: commit `e671659` su `HelpMe-mac`, ramo `main`.
Scritto il 3 settembre 2026.

La scuola ha rifiutato l'affidamento dei dati sanitari di minori a un servizio
esterno. La versione macOS non argomenta: smette di poterlo fare. Questo
documento dice cosa deve fare la versione Windows per arrivare allo stesso
punto, e **dove non può arrivarci** — che è la parte importante.

---

## 1. La cosa da decidere prima di scrivere una riga

Su macOS la garanzia non è nel codice: è nel pacchetto. `ENABLE_OUTGOING_NETWORK_CONNECTIONS`
è passato a `NO`, quindi l'app è in App Sandbox **senza**
`com.apple.security.network.client`, e a rifiutare le connessioni è il kernel.
Chi compra lo verifica da sé:

```bash
codesign -d --entitlements :- /Applications/HelpMe.app
```

**Su Windows oggi questo non è possibile.** `HelpMe.App.csproj` dichiara
`<WindowsPackageType>None</WindowsPackageType>`: l'app è non pacchettizzata,
quindi non gira in AppContainer e non ha capability da togliere. Rimuovere
`HttpClient` dal sorgente è necessario ma non è una *garanzia verificabile*:
è di nuovo una promessa, ed è esattamente ciò che la scuola ha rifiutato.

Le strade, in ordine di forza:

1. **MSIX senza `internetClient`** — è l'unica che dà parità vera: AppContainer
   nega la connessione a livello di sistema, e la capability si legge nel
   manifest del pacchetto installato. Costa il ritorno alla pacchettizzazione
   e la firma del pacchetto.
2. **Regola firewall in uscita** applicata dall'installer — enforcement reale
   ma amministrabile dalla scuola stessa, quindi ispezionabile e revocabile;
   più debole, ma onesta e spiegabile a un DPO.
3. **Solo rimozione del codice** — accettabile solo se accompagnata da una
   verifica statica sull'output pubblicato (nessun riferimento a
   `System.Net.Http`), dichiarata per quello che è.

Finché non è deciso, **la versione Windows non deve rivendicare la stessa
frase della versione macOS.** Dire «non può collegarsi» dove è vero solo
«non si collega» brucia l'unico argomento che abbiamo con questa scuola.

---

## 2. File da rimuovere

Corrispondenze uno a uno con quanto tolto su macOS:

| macOS (rimosso) | Windows |
|---|---|
| `Services/AI/AIEngine.swift` | `src/HelpMe.Core/Services/AI/AIEngine.cs` |
| `Services/AI/GeminiService.swift` | `src/HelpMe.Core/Services/AI/GeminiService.cs` |
| `Services/AI/LLMInferenceProtocol.swift` | `src/HelpMe.Core/Services/AI/LLMInferenceService.cs` |
| `Services/AI/SystemModelService.swift` | `src/HelpMe.Core/Services/AI/ISystemModelProvider.cs` + `src/HelpMe.App/Services/WindowsSystemModelProvider.cs` |
| `Services/RAG/SemanticSearchService.swift` | `src/HelpMe.Core/Services/RAG/SemanticSearchService.cs` |
| `Services/RAG/VectorStore.swift` | `src/HelpMe.Core/Services/RAG/VectorStore.cs` + `Models/DocumentChunk.cs` |
| (parte di `DocumentIndexer`) | `src/HelpMe.Core/Services/RAG/Embedder.cs` |
| `Services/Privacy/SourceTextScreening.swift` | `src/HelpMe.Core/Services/Privacy/SourceTextScreening.cs` |

**Da tenere:** `DocumentIndexer` limitato alla sola estrazione del testo (PDF,
docx, epub, rtf) — su macOS è stato svuotato di `chunkText` e degli embedding e
spostato in `Services/Documents/`. `StudentPseudonymizer` resta: il filtro dei
riferimenti clinici serve ancora al compositore della scheda PDP, anche senza
cloud.

Test corrispondenti da eliminare: `EngineSelectorTests.cs`, `GeminiErrorTests.cs`,
`SemanticSearchTests.cs`, più le parti di `AppViewModelTests.cs` che toccano il
motore.

---

## 3. Modello dei formati

`DidacticFormat.LocalComposition` perde `None` e guadagna `BuiltByTeacher`:

- `Always` → scheda PDP
- `FromStructuredText` → verifica equipollente
- `FromAnyText` → glossario, formulario, spiegazione semplificata
- `BuiltByTeacher` → mappa concettuale, quiz

Spariscono `SystemPromptTemplate`, `SystemPrompt(tablesSupported:)`,
`NeedsCloudQuality` e `PrefersModelWhenAvailable`. Nessun formato dipende più
da un modello: sei si compongono, due li scrive il docente negli editor
dedicati.

---

## 4. View model

Da `AppViewModel.cs` spariscono: `EngineOverride`, `SystemModelStatus`,
`EngineSelector`, `ActiveEngine`, la chiave API con il suo setter protetto,
`UsesRemoteModel`, lo screening del testo di partenza, `BuildPrompt`,
`Generate(engine)` e `FailureMessage`.

`EngineRationale` diventa `FormatRationale` e spiega **da dove nasce il
formato** invece di quale motore lo produce. `CanGenerate` guarda solo la
licenza e la composizione: `BuiltByTeacher` restituisce `false`, e la
generazione risponde dicendo dove si scrive («Scrivi il quiz», «Costruisci
mappa») invece di lasciare il pulsante muto.

L'importazione non indicizza più: estrae il testo e lo mette nell'editor, **in
coda** a quello che c'è già invece di sovrascriverlo, rispettando il limite
dell'editor. Con più file, ognuno preceduto da `## <titolo>`.

---

## 5. Interfaccia

Via il selettore del motore dalla barra in alto, la riga dei documenti
indicizzati, il pulsante «Indicizza testo» e l'avviso di invio al cloud. Il
pannello amministratore resta ma contiene **solo** la licenza.

Due dettagli non cosmetici:

- L'icona ✨ sul pulsante «Genera» va sostituita: è il simbolo con cui sia
  Apple sia Microsoft marcano l'IA, ed è il primo segnale che un docente
  diffidente legge male.
- Ogni occorrenza di «senza IA» nei messaggi di stato va tolta, non
  riformulata: in un'app che non ha l'IA, il confronto con una cosa che non
  esiste è rumore.

---

## 6. Chiave rimasta nel portachiavi

Chi ha già usato una versione con la chiave API se la ritrova salvata. Su macOS
la voce del portachiavi non si scrive più e viene **cancellata all'avvio**
(`KeychainStore.Key.legacyApiKey`). Su Windows va fatto l'equivalente sul
Credential Manager, per lo stesso motivo: una credenziale di un servizio che
l'app non usa più, trovata da chi controlla, vale come una smentita.

---

## 7. Test da aggiungere

Su macOS `HelpmeTests/OfflineGuaranteeTests.swift` presidia la garanzia dai due
lati: gli entitlement del processo in esecuzione e l'assenza di `URLSession`
nei sorgenti. **È stato verificato che sappia fallire** — rimettendo la
capability, il primo test si spegne.

L'equivalente Windows dipende dalla decisione del punto 1. In ogni caso è
sempre possibile il secondo lato: un test che rastrella i sorgenti di
`HelpMe.Core` e `HelpMe.App` e fallisce se compare `HttpClient`,
`WebRequest`, `Socket` o `System.Net`. Da scrivere per primo, perché è quello
che non dipende da nessuna scelta di packaging.

`Tools/distribuisci.sh` su macOS ora **rifiuta di consegnare** un pacchetto che
possa aprire connessioni. Lo script di pubblicazione Windows dovrebbe fare il
controllo corrispondente, qualunque forma prenda.

---

## 8. Cosa non cambia

Tutti e sette i formati restano, e nessuno è peggiorato: per sei la
composizione era già migliore di un modello. Restano il lettore con evidenziazione,
il righello, la sillabazione, i temi, la mappa navigabile, il quiz interattivo,
l'export Word, il registro GLO, le licenze ECDSA P-256 verificate offline.

Non è una versione ridotta. È la stessa app, senza la parte che la scuola non
voleva comprare.
