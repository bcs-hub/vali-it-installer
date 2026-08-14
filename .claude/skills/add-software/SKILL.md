---
name: add-software
description: Lisab uue tarkvara Vali-IT installerisse — kas Windowsi poolele (setup.ps1 / winget), WSL/Ubuntu poolele (install.sh / apt või eriloogika) või mõlemale. Kasuta kui kasutaja ütleb "lisa Windows alla X", "lisa WSL/Linux alla X", "lisa uus tarkvara/tööriist installerisse" vms.
---

# Uue tarkvara lisamine installerisse

See installer on config-driven: enamik lisamisi on üks rida configis, mõnikord
+ üks funktsioon. Vt `CLAUDE.md` ("Config drives everything") ja
`docs/ARCHITECTURE.md` ("## Laiendusmustrid") täieliku tausta jaoks — see
skill on samade reeglite praktiline tööjuhend.

Kasutaja annab tavaliselt ainult tarkvara nime ja sihtplatvormi (Windows
ja/või WSL). Ülejäänu tuleb tuvastada ise; kui miski jääb ebaselgeks (nt
winget id ei leia vastet), küsi kasutajalt, ära arva.

## 1. Tuvastamise samm — enne mistahes faili muutmist

Windowsi jaoks:
- Otsi winget id: `winget search "<nimi>"` ei tööta siit WSL dev-masinast
  (vt CLAUDE.md) — see EI ole eeldus vaid kohustuslik samm: palu kasutajal
  jooksutada `winget show <arvatav-id>` ja/või `winget search <nimi>` oma
  Windowsi PowerShellis ja tuua täpne väljund tagasi. Ära kunagi lisa
  winget id-d config'i enne, kui väljund on tegelikult nähtud (mitte
  ainult "levinud kuju nagu `Vendor.Product`" oletus) — täpne kirjapilt
  ja punktuatsioon on olulised.
- **Kui winget'is pole paketti üldse** (nt PromptFoo: `winget search`
  annab "No package found") — ÄRA jäta tarkvara Windowsi poolelt välja
  vaikimisi. Paku eriloogika-tee: kirjuta `Invoke-<Nimi>Setup` funktsioon
  otse `setup.ps1`-i (mitte config-rida `windows-apps.conf`-i), mustris
  nagu `Invoke-PromptfooSetup`/`Invoke-PostgresSetup`:
  - kontroll "kas juba olemas" (`Get-Command` PATH-il või muu tuvastus)
  - `Test-StateEntry`/`Add-StateEntry` samas 'app' kind-nimeruumis mis
    `Install-WindowsApps` kasutab, et re-run ja kokkuvõte käituksid ühtemoodi
  - paigaldus `Invoke-TickedJob`-iga (proof-of-life ticking), mitte otse
    foreground käsuga
  - `Add-Fail`/`Add-Ok` samamoodi kui teistel sammudel
  - kutse main flow'i (`setup.ps1` lõpuosa) õigesse kohta — kui tööriist
    sõltub Node'ist, PANE see PÄRAST `Install-WindowsApps`-i (Node.js
    LTS paigaldatakse seal), kasuta `Find-NpmCmd`-i (mitte bare `npm`,
    sest värske Node ei ole veel jooksva sessiooni PATH-il)
  See on suurem muudatus kui üks config-rida — ütle kasutajale selgelt,
  et tegu on koodilisandusega, mitte lihtsa reaga.
- Otsusta check-käsk: kui rakendus lisab midagi PATH-ile (CLI), kasuta
  seda binaari (nt `postman` harilikult EI ole PATH-il — GUI-äpid saavad
  `-` nagu Slack/Zoom/IntelliJ read).
- Otsusta kas vaja on fallback PDF-i (`docs/install/NNN-....pdf`) — kui
  seda veel pole, tuleb see kasutajal endal hiljem lisada; loo hetkel
  vaid platsihoidja viide, ÄRA leiuta sisu.

WSL/Ubuntu jaoks, otsusta kumb kolmest mustrist sobib:
1. **Lihtne apt-pakett** — kui `apt-cache show <pakett>` annab tulemuse.
2. **Eriloogikaga tööriist** (npm-global, custom install script, muu repo
   lisamine jne) — kui apt-is pole, või kui õige versiooni saamiseks on
   vaja midagi enamat kui `apt install`.
3. Uus samm-skript on VAJA ainult siis, kui see pole "paigalda tarkvara"
   vaid mingi muu Linuxi-poolne seadistus (git config, SSH-võtmed) — mitte
   tarkvara lisamisel.

## 2. Windowsi lisamine (`config/windows-apps.conf`)

Lisa üks rida vormingus:

```
winget-id | check-käsk | Kirjeldus (eesti keeles) | docs/install/NNN-Nimi-installimine-Windows.pdf | valikuline-ajavihje
```

- Kontrolli olemasolevaid ridu formaadi jaoks (`config/windows-apps.conf`).
- `check-käsk` = `-`, kui pole PATH-käsku (enamik GUI-äppe).
- PDF-number: vaata `docs/install/` suurimat olemasolevat numbrit + 1.
  Kui juhendit veel pole, ütle kasutajale, et fail on vaja lisada — ÄRA jäta
  viidet olematule failile ilma sellest teada andmata.
- `setup.ps1` ise EI vaja koodimuudatust — see loeb faili configist.

## 3. WSL/Ubuntu lisamine

### 3a. Lihtne apt-pakett → `config/packages.conf`

```
apt-pakett | kontrollkäsk | Kirjeldus (eesti keeles)
```

Kontrolli enne: `apt-cache show <pakett>` (vajab `apt-get update` kui
cache on tühi). Rohkem pole vaja teha — install JA verify hakkavad
automaatselt tööle (mõlemad loevad seda faili).

### 3b. Eriloogikaga tööriist → `config/ai-tools.conf` + `lib/installer.sh`

```
id | kontrollkäsk | Kirjeldus (eesti keeles)
```

Ja `lib/installer.sh`-i (jaotisse "custom tool installers") funktsioon
täpselt nimega `install_tool_<id>`, mustris nagu olemasolevad
(`install_tool_gh`, `install_tool_claude` jne):

- Kui tööriist vajab Node/npm-i (nt globaalne npm-pakett), tee samamoodi
  nagu `install_tool_claude`: `load_nvm`, `nvm use default`, siis
  `npm install -g <pakett>`.
- Jälgi reastikku config-failis, KUI tööriist sõltub eelnevast reast
  (nt npm-tööriistad peavad tulema pärast `node`-rida) — vt faili
  algusesse kirjutatud kommentaari järjekorra kohta.
- Idempotentsus on installer.sh mootori enda vastutus (`tool_available`
  kontroll enne kutset) — funktsioon ise ei pea seda kontrollima, aga
  peab olema ohutu, kui käivitatakse siiski uuesti.

Verify.sh ei vaja muudatust — see loeb sama faili.

## 4. Pärast muudatust — alati

1. **ShellCheck** uue/muudetud Bashi koodi peale (vt CLAUDE.md commands).
2. Kui puudutasid `setup.ps1` või configid Windowsi jaoks — PSScriptAnalyzer
   käsk CLAUDE.md-st.
3. Paku kasutajale smoke-testi (Docker, `install.sh --all` kaks korda),
   ÄRGE JAMAGE seda kunagi otse dev-masinal.
4. Kokkuvõtvalt näita kasutajale, mis read/failid lisati, ja mis (kui
   miski) jäi tema kätte (nt winget id kinnitus, PDF-juhendi sisu).
5. Ära commiti ise, kui kasutaja pole öelnud — järgi CLAUDE.md üldreeglit.
