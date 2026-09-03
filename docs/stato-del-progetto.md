# HelpMe — stato del progetto

Aggiornato il 3 settembre 2026, dopo la rimozione del motore generativo.

Questo file è per chi riprende in mano il lavoro fra un mese: Marco, la
controparte Windows, o una sessione futura che parte senza contesto. Dice
**dove stanno le cose, che cosa è stato deciso e soprattutto perché** — perché
fra un mese il perché è la parte che non ci si ricorda, e senza il perché una
decisione presa bene si rimette in discussione da capo.

---

## 1. I due codebase

| | macOS / iPadOS | Windows |
|---|---|---|
| Cartella | `~/Progetti/HelpMe/Helpme` | `~/Progetti/HelpMe-Windows` |
| Remote | `makiumjs/HelpMe-mac` | `makiumjs/HelpMe-windows` |
| Stack | Swift 6, SwiftUI, SwiftData | C# .NET 8, WinUI 3 |
| Test | 398 (383 XCTest + 15 Swift Testing) | 379 |
| Sorgente | ~9.500 righe | — |
| Motore generativo | **rimosso** | **ancora presente** |
| Permesso di rete | **assente** | presente |

Le due versioni hanno la stessa architettura, gli stessi compositori e gli
stessi parser, scritti due volte in due linguaggi. **La versione Swift è il
riferimento** quando un comportamento di là è ambiguo.

### Il nodo dei repository annidati

C'è una trappola da sistemare. `~/Progetti/HelpMe` è un repository git con un
solo commit (`d840f8a first commit`), e **dentro** ci sta
`~/Progetti/HelpMe/Helpme`, che è il repository vero con tutta la storia.
Puntano allo stesso remote.

Chi lavora dalla cartella esterna crede di vedere l'intero progetto come
«non tracciato» e conclude, sbagliando, che niente è mai stato committato. È
già successo in questa sessione. **Il repository su cui lavorare è quello
interno.** Vale la pena appiattire i due prima o poi.

---

## 2. La decisione che regge tutto: niente IA, niente rete

**Il fatto.** La scuola ha rifiutato di affidare a un servizio esterno dati
personali e sanitari di minori con disabilità. La pseudonimizzazione
funzionava e la chiave API era protetta, ma alcuni docenti non volevano l'IA
nel processo, punto.

**La scelta.** Non argomentare: togliere. La versione macOS non si limita a
non trasmettere i dati — **non ne ha il permesso**.
`ENABLE_OUTGOING_NETWORK_CONNECTIONS` è a `NO`, quindi il pacchetto è in App
Sandbox privo di `com.apple.security.network.client`, e a rifiutare le
connessioni è il kernel.

```bash
codesign -d --entitlements :- /Applications/HelpMe.app
```

**Perché è la mossa giusta e non un ripiego.** Le misurazioni fatte prima di
decidere dicevano che per sei formati su sette la composizione deterministica
è *migliore* di un modello. I tre guasti misurati sulla verifica equipollente
generata da un modello: rispondeva alle domande al posto dello studente,
sbagliava un calcolo di cento volte, inventava una griglia da 110 punti. Un
compositore che dispone i quesiti scelti dal docente non può fare nessuna
delle tre cose.

Il settimo formato — la spiegazione semplificata — era l'unico dove un modello
faceva qualcosa che l'app non sa fare: riscrivere le parole. Quel lavoro oggi
torna al docente, misurato con l'indice Gulpease e guidato frase per frase.

**Cosa è stato rimosso** (commit `e671659`, ripristinabile con `revert`): i
quattro file del motore, l'indice semantico — serviva solo a riempire i prompt
— e `SourceTextScreening`, la sorveglianza del testo verso il cloud, che senza
cloud avrebbe solo insegnato a ignorare gli avvisi.

**Cosa presidia la decisione:** `HelpmeTests/OfflineGuaranteeTests.swift`
controlla gli entitlement del processo in esecuzione e l'assenza di
`URLSession` nei sorgenti. È stato verificato che sappia fallire — rimettendo
la capability, il primo test si spegne. `Tools/distribuisci.sh` rifiuta di
consegnare un pacchetto che possa aprire connessioni.

---

## 3. L'asimmetria fra le due piattaforme

**È il punto più importante del documento, e il più facile da sbagliare.**

Su macOS la garanzia non è nel codice: è nel pacchetto, ed è verificabile da
un terzo senza fidarsi di noi.

Su Windows **oggi questo non è possibile.** `HelpMe.App.csproj` dichiara
`<WindowsPackageType>None</WindowsPackageType>`: l'app non è pacchettizzata,
quindi non gira in AppContainer e non ha capability da togliere. Rimuovere
`HttpClient` dal sorgente è necessario ma non è una garanzia verificabile: è
di nuovo una promessa, cioè esattamente ciò che la scuola ha rifiutato.

Le strade, in ordine di forza — la decisione è aperta:

1. **MSIX senza `internetClient`** — l'unica che dà parità vera. Costa il
   ritorno alla pacchettizzazione e la firma del pacchetto.
2. **Regola firewall in uscita applicata dall'installer** — enforcement reale
   ma amministrabile e revocabile dalla scuola stessa. Più debole, ma onesta.
3. **Sola rimozione del codice**, con verifica statica sull'output pubblicato
   e dichiarata per quello che è.

**Finché non è deciso, la versione Windows non deve rivendicare la frase della
versione macOS.** Dire «non può collegarsi» dove è vero solo «non si collega»
brucia l'unico argomento che abbiamo con questa scuola, e lo brucia per
sempre.

Il dettaglio operativo sta in [`allineamento-windows.md`](allineamento-windows.md),
con le corrispondenze file per file di cosa rimuovere.

---

## 4. Le decisioni da non rimettere in discussione

Ognuna è costata una misurazione o un errore. Riaprirle senza un fatto nuovo
è lavoro sprecato.

**Le licenze usano ECDSA P-256, non Ed25519.** La stessa licenza deve valere
sul Mac e sul PC di una scuola che ne compra una. .NET 8 non espone Ed25519, e
implementarlo vorrebbe dire aggiungere una libreria di crittografia di terze
parti. P-256 è di prima parte su entrambi, e l'interoperabilità è stata
verificata firmando in CryptoKit e verificando in .NET
(`rawRepresentation` ↔ `IeeeP1363FixedFieldConcatenation`).

**Non c'è revoca delle licenze.** Una verifica offline non può sapere che una
licenza è stata ritirata. Su una rete scolastica un controllo online sarebbe
un punto di rottura in più e contraddirebbe la promessa che l'app non parla
con nessuno.

**Una licenza scaduta ferma la generazione, mai la lettura.**
`LicenseGate.canRead` restituisce sempre vero, ed è una funzione e non una
costante sottintesa proprio perché un test possa presidiarla. Il materiale già
prodotto è dello studente che lo sta usando. Decisione presa su Windows e
confermata sul Mac: **anche la composizione senza modello si ferma**, perché
ora che sei formati su sette si producono così, lasciarla passare vorrebbe
dire che la licenza non protegge quasi più niente.

**Lo studente non vede le risposte.** Tutto il materiale che gli arriva passa
da `StudyTextPresenter`. Nel documento Word la chiave di correzione sta in
coda, dopo un'interruzione di pagina: al docente basta non stampare l'ultima
pagina.

**Il D.I. 182/2020 si cita nel testo coordinato con il D.I. 153/2023.** La
citazione sta in un posto solo per lato. Il decreto da solo è superato, e su
un documento che entra nel fascicolo di un alunno la citazione incompleta è un
difetto vero.

**La scheda PDP riporta le diciture della norma, non le parafrasa.** È il
motivo per cui fu il primo formato tolto a un modello: il valore del documento
sta nel riportare *esattamente* le parole della legge, e un modello che le
riscriveva un po' diverse a ogni generazione le peggiorava senza aggiungere
niente.

**La chiave API rimasta nel portachiavi si cancella all'avvio**
(`KeychainStore.Key.legacyApiKey`). Una credenziale di un servizio che l'app
non usa più, trovata da chi controlla, vale come una smentita.

---

## 5. Due misurazioni che hanno smentito un'ipotesi plausibile

Vale la pena tenerle scritte, perché tutte e due sembravano ovvie prima di
misurarle e tutte e due erano sbagliate.

**Il tempo di lettura non è il vincolo della verifica equipollente.** L'idea
era che il +30% fosse insufficiente e che simulare la lettura lo dimostrasse.
Misurato sul corpus: anche a 1,5 sillabe al secondo — dislessia grave — la
sola lettura occupa fra il 2% e l'8% del tempo concesso. Anche scalando a una
verifica reale tre o quattro volte più lunga si arriva al 25–30%. Il termine
dominante è la **produzione scritta**, che è la costante che nessuno sa
misurare. Corollario: solo 3 verifiche su 9 del corpus dichiarano una durata,
quindi su due terzi del materiale la funzione non avrebbe nemmeno l'input.

**La regola aritmetica ovvia di un controllo di coerenza è una macchina di
falsi positivi.** «La somma dei punti non torna al totale dichiarato» scatta
su 2 verifiche su 9 — e in 2 casi su 2 ha torto: è la situazione normale che
`pointsByQuestion` già gestisce distribuendo il resto. Riformulata dopo la
distribuzione: 0 violazioni. L'invariante regge già.

La lezione operativa: **il banco di prova dei falsi positivi va scritto prima
della regola, non dopo.** In venti minuti ha intercettato un errore che
sarebbe arrivato in produzione con l'aria di un rilievo normativo.

---

## 6. Cosa manca

### Serve Marco

- **Certificato Developer ID Application.** Manca nel portachiavi. Xcode →
  Settings → Accounts → Manage Certificates → + → Developer ID Application.
  L'iscrizione all'Apple Developer Program c'è già.
- **Credenziali di notarizzazione:**
  ```
  xcrun notarytool store-credentials "HelpMe" --apple-id "…" --team-id 775T7J89BJ --password <password-per-app>
  ```
  Finché mancano, l'app resta firmata «Apple Development» e si apre solo sui
  Mac registrati nell'account di chi la compila: sul portatile di un collega
  non si avvia affatto. `Tools/distribuisci.sh --controlla` dice a che punto è.
- **La coppia di chiavi delle licenze**, rimandata a app completa.
  `Tools/licenza.swift` la genera. Finché `LicenseVerifier.issuerPublicKey` è
  vuota **nessuna licenza viene applicata**: meglio una copia di sviluppo che
  funziona di una che si blocca da sola. La chiave privata non deve mai
  entrare nel repository.
- **Un docente di sostegno deve rivedere le diciture di `MeasureCatalog`
  prima della vendita.** È responsabilità professionale sua, non del software.

### Serve una decisione

- La strada del packaging Windows (sezione 3).
- Se e quando appiattire i due repository annidati (sezione 1).

### Non ancora fatto, ma già specificato

Dal brainstorm del 3 settembre sono usciti tre interventi, riordinati dopo le
misurazioni della sezione 5. Nessuno è implementato — Marco è in fase di test.

1. **Controllo di coerenza col PDP.** Non regole aritmetiche, che il codice
   già garantisce, ma di coerenza: misura dispensativa sui tempi attiva e
   intestazione che non dichiara il tempo maggiorato, formulario concesso e
   nessuno strumento elencato in prova. Sono le uniche che il codice attuale
   non soddisfa da sé. Primo passo: il corpus di auto-tolleranza.
2. **Registro degli esiti.** Il docente segna i punteggi sulla verifica
   generata; a giugno esce la verifica di efficacia delle misure che il
   D.I. 182/2020 impone come monitoraggio del PEI e che oggi si scrive a
   memoria la sera prima del GLO. È l'unico output che parla al dirigente
   scolastico, cioè a chi firma la licenza. Primo passo: estrarre `gridRows`
   da `EquipollenteComposer.grid(for:)`, 40 righe a comportamento invariato.
   Rischio da progettare *dentro* il codice: non esiste gruppo di controllo,
   e un numero che sembra scienza può diventare la motivazione con cui si
   toglie una misura compensativa a un minore. Il registro descrive, non
   conclude.
3. **Minuti concessi contro minuti usati.** Un campo e una riga di interfaccia:
   l'unica metrica sui tempi aggiuntivi che non richiede una costante
   inventata, ed è ciò che resta valido della simulazione del tempo dopo la
   misurazione.

---

## 7. Il materiale per l'esterno

- **Presentazione per l'acquirente** — documento commerciale, centrato sulla
  garanzia verificabile. Non nomina Windows, perché lì la stessa frase oggi
  sarebbe falsa.
- **`docs/audit-2026-08-29.html`** nel repository Windows — scritto per il
  capo dipartimento: cosa esce dal PC, cosa è stato provato eseguendolo e cosa
  no. Sul Mac l'equivalente non esiste ancora.
- **`docs/collaudo.md`** nel repository Windows — 26 prove manuali che i test
  automatici non possono fare. Vale la pena averne il corrispettivo qui: quasi
  tutti i difetti veri di questo progetto sono usciti dal documento prodotto e
  dai pulsanti cliccati, non dai test, che erano verdi mentre il difetto
  c'era.

---

## 8. La regola di lavoro che ha retto meglio

**Aprire il documento prodotto e cliccare i pulsanti.** Non è un modo di dire:
i cinque pulsanti morti, la perdita del lavoro salvato a ogni avvio, i quattro
quesiti persi su cinque in una verifica mista, l'errore di calcolo di cento
volte — nessuno di questi è stato trovato da un test. Tutti sono stati trovati
guardando l'uscita.

I test servono a non farli tornare. Non servono a trovarli.
