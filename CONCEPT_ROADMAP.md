# Dotfiles v2 — implementační plán (chezmoi + Age + EJSON, multi-OS, multi-shell)

> **Poznámka pro implementujícího agenta:** tento dokument je navržený jako samostatný a úplný —
> nepředpokládá žádný přístup k historii konverzace, ve které vznikl, ani k paměti (`memory`)
> jiného Claude Code účtu/stroje. Pokud pracuješ na jiném stroji/účtu (např. na private profilu,
> odděleně od work profilu), **měl bys mít tenhle soubor k dispozici přes git** — je commitnutý
> v tomto repu vedle `README.md`, `ENCRYPTION_SETUP.md`, `DAILY_WORKFLOW.md`, `ALIASES.md`, takže
> je dostupný odkudkoliv přes `git clone`/`chezmoi update`. Repo samotné je `~/Devel/dotfiles`
> (dev repo, ne chezmoi source-path — viz "Two-repo mental model" v `DAILY_WORKFLOW.md`).

## Kontext

Repo `~/Devel/dotfiles` obsahuje promyšlený, ale **reálně nikdy nenasazený** koncept: chezmoi
jako dotfiles manager, Age + EJSON pro šifrování secrets, dva kryptograficky izolované profily
(`personal`/`work`), každý s vlastním Age/EJSON keypairem a "evaultem" (zašifrovaný JSON blob se
secrets). Mechanika existuje a vypadá funkční (`helpers/setup-encryption.sh`,
`private_dot_local/bin/executable_edit-evault`, `.chezmoiscripts/`), ale nikdy neprošla reálným
denním provozem — celé je to zatím POC.

**Cíl tohoto plánu:** uvést koncept do praxe a zároveň ho rozšířit o:
- víc OS (Linux včetně WSL2, macOS, nativní Windows) pro oba profily,
- víc shellů (bash, fish, PowerShell 7),
- obecný vzor sdílení konfigurace (common/personal/work) použitelný na cokoliv, ne jen na shell,
- instalaci nástrojů/balíčků napříč platformami,
- novou osu **role** (workstation/server), nezávislou na identitě (personal/work).

Protože nic z tohoto není reálně nasazené, **není důvod stavět opatrně "od nejmíň rizikového"**
— jde stavět rovnou to, co má být použité denně. První reálný cíl: **Mac + fish + Ghostty +
starship** (viz sekce "Pořadí implementace").

---

## 1. Potvrzené požadavky a fakta o prostředí

- **Dvě izolované identity**: `personal`, `work` — oddělené Age/EJSON klíče, oba profily už mají
  reálně vygenerované klíče (viz `.chezmoi.yaml.tmpl`). Dotfiles sdílejí některé věci (obecné
  aliasy), ale jiné musí zůstat striktně oddělené (např. `known_hosts`/`ssh config` s FQDN
  různých strojů — ty nesmí uniknout mezi světy).
- **OS pokrytí**: Linux (WSL2 = jen distro varianta Linuxu, žádná zvláštní větev — "jako Fedora
  vs. Debian"), macOS, nativní Windows (ne jen WSL2) — pro oba profily.
  - `personal` profil na Macu zatím **nemá reálný stroj** — zůstává prázdný scaffold, jen
    struktura připravená na budoucí doplnění.
  - `work` profil na Macu **má reálný stroj** — naplní se jako první.
- **Shell pokrytí**: **fish** (první reálný cíl, HOTOVO), bash, **zsh** (přidáno 2026-08-01 —
  uživatel bude psát skripty v zsh kvůli přenositelnosti, zsh je navíc default shell na macOS),
  PowerShell 7 (ne Windows PowerShell 5.1). Bash a zsh mají pro `alias`/`export` syntaxi
  **bajtově identickou** (a fish `abbr` nemá nativní obdobu ani v jednom) → **sdílejí jeden
  renderer/výstupní soubor** (sekce 3.3), ne dva samostatné. Celkem tedy tři cílové renderery
  (fish / bash+zsh / PowerShell) ze stejného zdroje dat.
- Jeden zdroj pravdy je žádoucí pro jednoduchá data (aliasy, env proměnné) sdílená napříč shelly.
  Composed bash funkce a prompt/barvy **nejdou mechanicky přeložit** mezi shelly a musí se psát
  ručně — **s výjimkou bezstavových funkcí**, viz nová sekce 3.8.
  **Důležitá korekce (starship NENAHRAZUJE klasický prompt/color mechanismus, jen ho doplňuje):**
  starship (sekce 6) běží jen tam, kde je nainstalovaný a nakonfigurovaný — typicky dev
  workstation s Ghostty. Ale uživatel skáče i do jiných lokálních terminálů bez starship, a
  hlavně se připojuje na **svoje vlastní vzdálené servery** — SSH lokální terminál nijak neovlivní
  chování vzdáleného shellu (výjimka: `$TERM`, protokolem vyžadovaný vždy; jinak jen proměnné,
  které vzdálený `sshd_config` explicitně povolí přes `AcceptEnv`, a to funguje jen na strojích,
  které sám spravuješ). Barvy/prompt na vzdáleném stroji pochází **výhradně** z toho, co je
  nasazené přímo na něm — ne z lokálního terminálu. Proto **klasický nativní prompt (dnešní
  `dot_bashrc.d/00-colors.sh`+`99-prompt.sh` bash `PS1` logika, plus fish ekvivalent nativní
  `fish_prompt` funkcí — psané ručně zvlášť pro každý shell) zůstává první-třídní, aktivně
  udržovaná součást konceptu, nasazená UNIVERZÁLNĚ (všude, bez ohledu na roli/profil)** — ne
  legacy věc nahrazená starshipem. Starship se navíc nasadí tam, kde ho chceš (typicky
  workstation) a přirozeně vrstevnatě přebije klasický prompt (inicializuje se na konci rc
  souboru) — kde není přítomný, zůstane viditelný klasický prompt ze stejných dotfiles.
- Stejný **common/personal/work vzor** se má použít obecně na libovolný config, ne jen na shell:
  git config, ssh config, editor config, Ghostty, starship.
- Nová osa **role** (`workstation` vs. `server`), ortogonální k `profile` — server patří pod
  stejnou identitu/klíče jako personal nebo work, role mění jen instalované balíčky a širší
  konfiguraci/chování. Precedens už v repu: `vm_type` (virtualbox/vmware) v `packages.yaml`.
- **Nový fakt o stroji: `has_gui`** (bool), ortogonální k `role` i `profile` — workstation role
  může být GUI (Mac s Ghosttym) i headless (minimalistický Linux dev stroj bez GUI, uživatel má
  reálně takový). Aliasy/env proměnné/fish/starship jsou vždy relevantní bez ohledu na GUI (čistě
  shell-úrovňové, fungují přes SSH/konzoli stejně jako v GUI terminálu) — jen GUI-závislé věci
  (Ghostty) se mají podmínit `has_gui`, viz sekce 6/7. Zjišťuje se jednou při `chezmoi init`
  (`promptBoolOnce`, stejný vzor jako volba profilu — jen lokální chezmoi config, nikdy v gitu).
- **Serverové prostředí**: většina Proxmox homelab VM, 1-2 externí na Oracle Cloud (přístup ke
  službám zvenčí). Všechny se zatím provisionují nabootováním do základního stavu a pokračováním
  přes SSH — **ne zero-touch**. Pro tuhle fázi: server bootstrap = SSH-driven/interaktivní, stejný
  Age-passphrase flow jako workstation; role zatím mění jen výběr balíčků/configu.
- **Password manager**: self-hosted Bitwarden, dvě oddělené instance/URL (personal, work) — obě
  dnes obsahují Age passphrase daného profilu. Bitwarden Secrets Manager (dedikovaný produkt pro
  machine secrets) je cloud-only a nejde použít se self-hosted instancí.
- **Editor**: nano (jistota) / micro (líbí se) / Zed (zvažuje se) na Linux/Mac, Windows zatím
  neřešeno. Pro nano/vim: **žádné secrets, plně sdílené common** napříč personal/work — potvrzeno.
  Až přijde Zed (cloud/AI funkce, telemetrie), tenhle předpoklad pravděpodobně přestane platit
  (firemní politika k AI nástrojům, jiný LLM endpoint práce/osobní, API klíč jako secret) —
  neřešit teď, řešit až při reálném nasazení.

---

## 2. Architektura — obecné mechanismy

### 2.1 Izolace scope (personal/work × OS × role)

Zobecnit dnešní `.chezmoiignore.tmpl` masking (dnes používaný pro `dot_bashrc.d/{personal,work}`
a `secrets/`) na obecný vzor pro personal/work × OS × role — **fyzická nepřítomnost** špatné
varianty na disku, ne jen podmínka v aplikaci. Tohle je nosná konstrukce, na které stojí
všechno ostatní — musí se postavit a ověřit jako první.

**Reálný nález 2026-08-01 — `~/.bashrc.d/*` auto-sourcing NENÍ bezpečný cross-distro předpoklad.**
Celý dnešní bash mechanismus (`00-loader.sh` řeší jen personal/work PODadresáře) spoléhá na to,
že **OS-default `~/.bashrc` už sám sourcuje `~/.bashrc.d/*`** (top-level). Ověřeno přímo na
reálném Fedora 44 lab VM — má to. **Ale ověřeno i pro Ubuntu (Launchpad changelog balíčku
`bash`): Ubuntu 24.04 LTS tohle nemá vůbec**, a i krátký pokus v Ubuntu 25.10 (bash
5.2.37-2ubuntu2) sourcoval jiný, **systémový** adresář (`/etc/bash.bashrc.d`, ne `~/.bashrc.d`)
a byl zase odstraněn v 26.04. **Řešení: `.chezmoiscripts/run_after_ensure-bashrc-sourcing.sh.tmpl`**
— idempotentní skript (plain `run_` prefix = běží při KAŽDÉM `chezmoi apply`, ne jen jednou, pro
self-healing kdyby OS reinstall/update `~/.bashrc` resetoval): `grep` na `.bashrc.d` v `~/.bashrc`,
pokud chybí, připojí na konec identický blok, jaký má Fedora nativně. Ověřeno: no-op na systému,
co to už má (Fedora), správně přidá a je idempotentní (druhé spuštění nic nezdvojí) na systému,
co to nemá (simulovaný "Ubuntu" test), a výsledek se reálně nasourcuje ve skutečném bash.

**Pravidlo pro kódování scope/OS do zdrojové struktury:** přizpůsobit tomu, co cílový formát
reálně potřebuje:
- **Adresářový strom** u cílů, které jsou přirozeně stromem (např. `dot_bashrc.d/{personal,work}/`).
- **Jméno souboru** u cílů, které musí být jeden plochý adresář (SSH `conf.d/` — viz 2.3).
- **Template-kompozice** u formátů bez include (npmrc, starship.toml — viz 2.5, 6).

### 2.2 Kompozice konfiguračních souborů — podle podpory nativního include

- **Formát umí nativní include** → necháme na nástroji; chezmoi jen umísťuje/maskuje fragmenty.
- **Formát neumí include** → composition za běhu `chezmoi apply` přes `.chezmoitemplates/`
  partiály (dnes používané jen pro skripty, stejný princip funguje i pro obsah configů), secret
  hodnoty tažené z evaultu přes `output "ejson" "decrypt" ...` (EJSON klíč je v tu chvíli už
  odemčený na disku díky `run_once_before_init_age.sh.tmpl` — ale **žádný dnešní template takhle
  hodnotu z evaultu netahá, tenhle kus je nepostavený** — první reálné využití viz sekce 4.2).
- **`known_hosts`** vyloučen z tohoto vzoru — SSH si ho za běhu sám dopisuje; řešit jako seed,
  ne jako spravovaný/mergovaný soubor.

### 2.3 Git config (ověřeno)

`[include] path = ...` na neexistující soubor **tiše no-opuje** (dokumentované chování). Git u
konfliktní hodnoty **vyhrává poslední** → pořadí: common → profil → profil+OS (nejobecnější
první, nejspecifičtější poslední, aby mohl přepsat).

```
dot_config/private_git/                           # ne private_dot_config/git/, viz níže
  common.gitconfig
  personal/{common,linux,mac,windows}.gitconfig
  personal/hosts/{github,gitlab,...}.gitconfig    # per-host e-mail, viz níže
  work/{common,linux,mac,windows}.gitconfig
  work/hosts/{github,gitlab,...}.gitconfig
```

**Korekce (2026-08-01, stejná chyba jako u `~/.zshrc`/`~/.ssh/config`, viz §2.1/§3.3/§2.4):**
původně navržený **statický `dot_gitconfig`** (chezmoi plně vlastní celý `~/.gitconfig`) by
potichu smazal reálný, dnes používaný obsah — `[user] name/email` (work identita). **Oprava:
`~/.gitconfig` zůstává user/OS-vlastněný**, stejně jako `~/.bashrc`/`~/.zshrc`/`~/.ssh/config`.
`.chezmoiscripts/run_after_ensure-gitconfig-includes.sh.tmpl` idempotentně připisuje
`[include]`/`[includeIf]` bloky, pokud chybí. **Na rozdíl od SSH/bash zde nestačí jeden sentinel
řádek** — git nemá directory-glob include (žádné `Include *.conf`/`source *` obdoba), každý
fragment je samostatný explicitní řádek → script je **idempotentní per blok** (`ensure_include_block`
funkce, kontroluje/připisuje každý blok zvlášť), takže přidání nového host-fragmentu (např.
gitlab) v budoucnu stačí přidat jako další volání funkce — self-healing na dalším apply, beze
změny už existujících bloků. Reálný `[user]` blok zůstává na svém místě (dřív než náš append);
nový `work/common.gitconfig` (se stejnou hodnotou) běží první dobu duplicitně vedle něj — stejné
přechodné chování jako u zsh/SSH, manuální úklid starého bloku nechán na uživateli.

Volitelné rozšíření později: `[includeIf "gitdir:...")]` pro jemnější identity podle adresáře
repozitáře (git to podporuje nativně s glob patterny) — neřešit v první iteraci.

**Doplněno 2026-08-01 — dotaz uživatele: jde per-server (GitHub/GitLab/self-hosted) určit jiný
git e-mail na úrovni globálního configu?** Ano — ověřeno (WebFetch/WebSearch, oficiální git-scm.com
dokumentace + více nezávislých zdrojů). Git **od verze 2.36 (duben 2022)** umí
`[includeIf "hasconfig:remote.*.url:<glob-pattern>"]` — podmínka se vyhodnotí jako splněná, pokud
**aspoň jeden** remote v aktuálním repozitáři odpovídá vzoru (podporuje `**` na segmenty cesty):

```gitconfig
[user]
    email = default@example.com          # fallback — MUSÍ být PŘED includeIf bloky (viz níže)

[includeIf "hasconfig:remote.*.url:git@github.com:*/**"]
    path = ~/.config/git/hosts/github.gitconfig
[includeIf "hasconfig:remote.*.url:git@gitlab.com:*/**"]
    path = ~/.config/git/hosts/gitlab.gitconfig
[includeIf "hasconfig:remote.*.url:git@git.internal.example.com:*/**"]
    path = ~/.config/git/hosts/selfhosted.gitconfig
```

**Kritický nález při implementaci (2026-08-01) — vzorek výše upraven, původní byl reálně
nefunkční:** pattern `git@github.com:**` (bez `/` bezprostředně před posledním `**`) **v testu
nikdy nezafungoval** — potvrzeno na reálném remote tohoto repa (`git@github.com:polachz/dotfiles.git`).
Man page říká, že `**`/`/**` "match multiple components", ale tahle schopnost se aktivuje jen když
`**` bezprostředně následuje po `/` — u SCP-style URL je znak před poslední částí cesty `:`
(dvojtečka), ne `/`, takže holé `**` po dvojtečce se chová jako obyčejný jednosegmentový `*` a
nenamatchuje `org/repo.git` (obsahuje `/`). Oprava: `git@github.com:*/**` (empiricky ověřeno,
funguje). Pro `https://` styl remote (kde `/` už za doménou přirozeně je) funguje i holé
`https://github.com/**`. **Kvůli tomuhle je potřeba pro každý host DVA `includeIf` bloky** (SCP i
https varianta remote URL), ne jeden — oba směřují na stejný `hosts/*.gitconfig` fragment.

**Důležité nuance:**
- **Pořadí v souboru se počítá** stejně jako u obyčejného `[include]` (sekce výše) — výchozí/fallback
  `[user]` blok musí být **před** `includeIf` bloky, jinak by pozdější statický blok přepsal to,
  co host-specific include nastavil.
- Vkládané soubory (`path = ...`) **nesmí samy obsahovat definici remote URL** — git řeší
  potenciální kruhovou závislost (podmínka se odvíjí od remote, remote nesmí být uvnitř
  podmíněného souboru) tímhle omezením natvrdo.
- **Hodnotu e-mailu (např. GitHub "keep my email private" noreply adresu tvaru
  `id+username@users.noreply.github.com`) git sám neodvodí** — je to nastavení specifické pro
  daný účet na daném hostu (GitHub Settings → Emails), musí se ručně opsat do odpovídajícího
  `hosts/*.gitconfig` fragmentu. GitLab má obdobnou "commit email privacy" funkci, ale formát
  proxy adresy se liší (a u self-hosted GitLabu závisí na doméně instance) — není to samo o sobě
  cross-host kompatibilní, každý host/účet potřebuje svůj vlastní fragment.
- **Fragmenty patří pod existující profile-scoped strukturu** (`personal/hosts/github.gitconfig`,
  `work/hosts/github.gitconfig`) — ne jako samostatná neprofilovaná vrstva — protože work a
  personal GitHub účet mají jinou noreply adresu, a `.chezmoiignore` už beztak zajišťuje, že
  personal stroj nikdy fyzicky nemá work fragmenty na disku (stejný princip jako zbytek konceptu).
- **Noreply adresa NENÍ citlivá** (je navržená tak, aby se bezpečně objevovala veřejně v commit
  historii) → patří jako **plaintext fragment**, ne do evaultu. Pokud by některý self-hosted host
  neměl privacy-proxy funkci a uživatel by tam chtěl skutečnou osobní adresu, tenhle konkrétní
  fragment jde udělat jako `.tmpl` s `output "ejson" "decrypt" ...` (stejný mechanismus jako
  plánovaná env-var secret injekce, sekce 4.2) — ne každý `hosts/*.gitconfig` musí být static.
- **Caveat (ověřeno, reálné omezení):** ne všechny nástroje `hasconfig:remote.*.url:` podporují
  stejně dobře jako čistý `git` CLI — nahlášený problém u VS Code vestavěné Git integrace
  (nerozpozná správně e-mail nastavený přes tenhle mechanismus, i když `git config user.email`
  na příkazové řádce vrátí správnou hodnotu). Nezjištěno, jestli uživatel VS Code Git integraci
  reálně používá — ověřit až při implementaci (`git config user.email` v repu vs. co ukazuje
  editor).

Zdroje ověření: [git-scm.com git-config dokumentace](https://git-scm.com/docs/git-config),
[Customizing Git Configuration Based on Remote Repositories](https://markoivancic.from.hr/customizing-git-configuration-based-on-remote-repositories),
[Manage Multiple Git Identities With Conditional Includes](https://ingo-richter.io/post/2025/manage-multiple-git-identities-with-conditional-includes/),
[VS Code issue #160002](https://github.com/microsoft/vscode/issues/160002).

**IMPLEMENTOVÁNO a ověřeno (2026-08-01) — jen mechanismus, bez hodnoty** (uživatel: "jen připravit
`includeIf` mechanismus, e-mail doplním sám později"). `work/hosts/github.gitconfig` je záměrně
prázdný scaffold s komentářem/instrukcí, ale se skutečně funkčním `includeIf` mechanismem (viz
kritický nález o `**` vs `*/**` výše — bez něj by byl mechanismus tiše nefunkční napořád).
`.chezmoiscripts/run_after_ensure-gitconfig-includes.sh.tmpl` připisuje pro GitHub **dva**
`includeIf` bloky (SCP `git@github.com:*/**` i `https://github.com/**` styl remote), oba na
stejný fragment. Ověřeno: přejmenováno z `private_dot_config/git/` na `dot_config/private_git/`
kvůli stejné "inconsistent state" kolizi jako u Ghostty (`.config` je použité i jinde
netemplatovaně). Sandboxový `chezmoi apply --exclude=scripts` pro `work`/`personal` (masking
podle `.config/git/{personal,work}` adresáře — na rozdíl od SSH zde stromová struktura stačí,
git include nepotřebuje plochý adresář). Script otestován izolovaně s `HOME=/tmp/...`: dvojí
spuštění dá identický checksum (idempotence); ruční smazání jednoho z appendnutých bloků + další
spuštění doplní **jen ten chybějící** (self-healing per blok — se známým, akceptovaným omezením:
znovu-připsaný blok jde vždy na konec souboru, takže pokud by šlo o `[user]` fallback blok
smazaný zpod již existujícího `includeIf`, obnoví se v ŠPATNÉM pořadí — okrajový případ, neřešeno
kvůli nízké pravděpodobnosti). End-to-end test na 3 scénářích (bez remote / SCP GitHub remote /
https GitHub remote) s reálným `git config --includes user.email` (`HOME=` na testovací sandbox,
nikdy reálný `~/.gitconfig`) potvrdil správnou fallback→override logiku včetně skutečné noreply
hodnoty. Reálný `~/.gitconfig` zůstal po celou dobu byte-identický.

### 2.4 SSH config (ověřeno)

`Include ~/.ssh/conf.d/*.conf` funguje s wildcardem, ale SSH má **opačnou sémantiku než git —
vyhrává PRVNÍ nalezená hodnota** pro danou direktivu, ne poslední (výjimka: pár kumulativních
direktiv jako `IdentityFile` se sčítá, nepřepisuje). Protože glob expanduje abecedně, musí být
specifičtější fragmenty abecedně dřív → **číselný prefix v názvu souboru**:

```
private_dot_ssh/
  conf.d/
    50-work-redhat.conf                 # Host *.redhat.com — GSSAPI
    50-work-labvms.conf                 # Host maclab / Host windev
    90-common.conf                      # nejobecnější naposled, jen jako fallback
```

Scope/OS je zakódovaný v **jméně souboru** (ne v adresáři, protože cíl musí být jeden plochý
adresář), `.chezmoiignore.tmpl` maskuje podle vzoru jména, ne podle adresáře.

**Korekce (2026-08-01, stejná chyba jako u `~/.zshrc`, viz §2.1/§3.3):** původní návrh výše
počítal se **statickým `private_dot_ssh/private_config`** — chezmoi by tak plně vlastnilo celý
`~/.ssh/config`. Než se to postavilo, přečetl jsem si (read-only) reálný soubor na tomhle stroji
a našel skutečný, dnes používaný obsah: GSSAPI nastavení pro `*.redhat.com` a `Host maclab`/
`Host windev` (UTM lab VM z §8). Statická náhrada celého souboru by tohle potichu smazala.
**Oprava: `~/.ssh/config` zůstává user/OS-vlastněný, stejně jako `~/.bashrc`/`~/.zshrc`** — jen
malý idempotentní `Include ~/.ssh/conf.d/*.conf` řádek se připíše, pokud chybí
(`.chezmoiscripts/run_after_ensure-sshconfig-sourcing.sh.tmpl`, stejný vzor jako
`run_after_ensure-{bashrc,zshrc}-sourcing.sh.tmpl`). Nalezený obsah byl přeřazen (potvrzeno
uživatelem) do `work` scope jako `50-work-redhat.conf`/`50-work-labvms.conf` — i lab VM, přestože
jde o testovací infrastrukturu nezávislou na identitě, protože tenhle Mac je dnes work-profil
stroj.

**Manuální cutover, nutně vědomě odložený:** dokud existují ve skutečném `~/.ssh/config` staré
`Host *.redhat.com`/`maclab`/`windev` bloky, SSH first-match-wins zajistí, že **vyhrávají ony**
(jsou v souboru dřív než nově připsaný `Include`) — nové `conf.d/50-work-*.conf` fragmenty jsou
neaktivní duplicity, dokud je uživatel ručně nesmaže ze skutečného souboru. Chezmoi nemůže
bezpečně mazat řádky, které samo nepřidalo — stejná nedořešená otázka jako u starého obsahu v
`~/.zshrc`.

**Kritický nález při testování — `Include` uvnitř neshodujícího se `Host` bloku se tiše
ignoruje** (zdokumentovaný OpenSSH gotcha, ne bug v našem kódu): pokud `Include` řádek následuje
po dřívějším `Host`/`Match` bloku, který pro daný cílový host NEPLATÍ (přesně scénář reálného
`~/.ssh/config` — `Host *.redhat.com` na začátku, `Include` až za ním), OpenSSH **soubor přečte**
(vidět i ve `ssh -v` debug výstupu), ale **obsah aplikuje jen pro hosty, na které platil i ten
předchozí blok** — i když included soubor má vlastní `Host` řádky. Ověřeno: `ssh -G maclab`
nezohlednil `Host maclab` z `conf.d/50-work-labvms.conf` vůbec, dokud se před `Include` nepřidal
resetovací `Host *`. **Oprava zapracována do scriptu**: `run_after_ensure-sshconfig-sourcing.sh.tmpl`
připisuje `Host *\nInclude ~/.ssh/conf.d/*.conf` (ne jen `Include` samotný) — `Host *`
bezpodmínečně resetuje kontext bez ohledu na cokoliv dřívějšího v souboru. Bez týhle opravy by
byl celý mechanismus nespolehlivý pokaždé, když by reálný soubor obsahoval jakýkoliv `Host` blok
před naším připsaným řádkem — přesně tenhle případ.

**IMPLEMENTOVÁNO a ověřeno (2026-08-01):** sandboxový `chezmoi apply --exclude=scripts` pro
`profile=work` i `profile=personal` (work vidí všechny 3 fragmenty, personal jen `90-common.conf`
díky `.chezmoiignore.tmpl` maskingu podle jména souboru). Script `run_after_ensure-sshconfig-sourcing.sh.tmpl`
otestován izolovaně s `HOME=/tmp/...` — idempotence (dvojí spuštění = identický checksum),
zachování existujícího obsahu, perms `700`/`600`. **Nález k `private_` atributu**: `private_`
na rodičovském adresáři (`private_dot_ssh/`) nastaví 0700 na adresář, ale NE automaticky 0600 na
soubory uvnitř `conf.d/` — každý soubor potřebuje vlastní `private_` prefix v názvu
(`private_dot_ssh/conf.d/private_50-work-redhat.conf` atd.), jinak zůstanou defaultní `644`
(stejná nekonzistence existuje už dnes i u Ghostty configů, tam ponechána beze změny, tady
opravena kvůli vyšší citlivosti `~/.ssh/`). `ssh -G <host>` (přes `-F`/`HOME=` na testovací
sandbox, NIKDY proti reálnému souboru) potvrdil správné efektní rozlišení pro `maclab`/`windev`
(HostName/User/StrictHostKeyChecking), `foo.redhat.com` (GSSAPI + SetEnv) i libovolný jiný host
(jen SetEnv z common fallbacku). Reálný `~/.ssh/config` zůstal po celou dobu byte-identický
(checksum ověřen před/po).

**`known_hosts`** se nespravuje tímto mechanismem vůbec (viz 2.2) — SSH si ho sám dopisuje za
běhu, statický/mergovaný soubor by mohl kolidovat s tím, co se SSH lokálně naučí.

**Ghostty `TERM=xterm-ghostty` přes SSH (ověřeno, reálný problém pro tenhle koncept):** Ghostty
nastavuje `TERM=xterm-ghostty`; vzdálené stroje bez odpovídajícího terminfo záznamu (typicky
minimal Linux VM/homelab servery) na to spadnou chybou "missing or unsuitable terminal" u
interaktivních programů (`nano`, `vim`, `htop`). Doporučené řešení: přidat do **common** SSH
fragmentu (nejobecnější, tedy `90-common.conf` v pořadí z 2.4)
```
Host *
    SetEnv TERM=xterm-256color
```
(vyžaduje OpenSSH ≥8.7 na klientovi). Tohle je robustnější než Ghostty vlastní
`shell-integration-features = ssh-env,ssh-terminfo` řešení, které **nefunguje pro nic, co
nevolá `ssh` přes interaktivní shell** (cron, git/scp/rsync přes ssh, mosh) — a nezávisí na
tom, jestli vzdálený stroj má aktuální terminfo databázi. Cena: ztráta pár pokročilých
Ghostty-specifických schopností (barevné podtržení) — zanedbatelné proti garantované
kompatibilitě všude.

### 2.5 Formáty bez nativního include (npmrc, starship.toml, ...)

Skládají se přes `.chezmoitemplates/` partiály za běhu `chezmoi apply` — jeden zdrojový
`.tmpl` soubor volá `{{ template "fragment-name" . }}` pro common/profil/profil+OS kousky a
výsledek je jeden kompletní finální soubor. Viz konkrétní příklad starship v sekci 6.

---

## 3. Datový model: aliasy

### 3.1 Klíčové chezmoi chování (ověřeno v oficiální dokumentaci)

Soubory pod `.chezmoidata/` se **mergují do kořene datového slovníku podle abecedního pořadí
souborů** — **cesta/adresář souboru vůbec neovlivňuje, pod jakým klíčem data skončí**. Merguje
se jen obsah YAML (rekurzivně, ale **jen slovníky** — seznamy se při kolizi klíče **přepíšou**,
ne sloučí, tím abecedně pozdějším souborem). Důsledky:
- Adresářová struktura pod `.chezmoidata/aliases/...` je **čistě organizační pro člověka** — scope
  a kategorie musí být explicitně v obsahu YAML, ne odvozené z cesty k souboru.
- **Jména kategorií musí být unikátní napříč celým repem** — kolize by způsobila tiché přepsání
  jednoho seznamu druhým, ne sloučení.

### 3.2 Schéma

```yaml
# .chezmoidata/aliases/common/ls.yaml  (cesta = jen orientace pro člověka)
aliases:
  common:
    categories:
      ls:
        - name: ll
          command: ls -l --color
          kind: abbr           # default; alias jen pro výjimky (viz níže)
          description: List all files and folders in long format

# .chezmoidata/aliases/common/misc.yaml — catch-all, víc mikrokategorií v jednom souboru
aliases:
  common:
    categories:
      week:
        - name: week
          command: date +%V
          description: Get week number
      checksums:
        - name: sha
          command: shasum -a 256
          description: SHA-256 checksum shortcut
```

- **`kind: alias | abbr`, default `abbr`.** `abbr` = fish abbreviations — na rozdíl od `alias` se
  po mezeře fyzicky rozbalí na příkazové řádce (vidíš/upravíš plný příkaz před enterem). Default
  je `abbr` záměrně: historie ukládá rozbalený příkaz (ne nepoužitelnou zkratku), kontrola před
  odesláním destruktivních příkazů (`shutdownnow`), přenositelnost při kopírování příkazu jinam.
  **Výjimka — vždy `kind: alias` (tiché):** skupina "stejné jméno, jen přidání flagů", kde není
  co odhalovat: `grep`/`fgrep`/`egrep` (`--color=auto`), `ping` (`-c 5`), `sudo` (trailing-space
  trik).
- **`description`** je povinné — dvojí využití: generovaná dokumentace (`ALIASES.md`, viz 3.4) i
  komentář v renderovaném souboru.
- **`command`** může být prostý řetězec (platí všude) nebo mapa s `default` + per-OS override.
  Klíčové slovo **`skip`** = "tahle položka na daném OS vůbec neexistuje/nerenderuje se" (ne
  `null`/`false` — ty jsou v Go template stejně "falsy" jako chybějící klíč, nešly by rozlišit
  bez extra `hasKey` kontroly):
  ```yaml
  - name: ll
    command:
      default: "ls -l --color"
      darwin: "ls -l -G"
  - name: some-linux-only-thing
    command:
      default: "..."
      windows: skip
      darwin: skip
  ```
  Render šablona: `{{ $val := index $entry.command $osKey }}` → `skip` = vynechat úplně,
  prázdné/chybí = použij `.default`, cokoliv jiného = použij jako override.

### 3.3 Renderery (per shell target)

Jedna render šablona na cílový shell, všechny čtou **stejná** `.chezmoidata`:
- **fish**: `dot_config/fish/conf.d/aliases.fish.tmpl` → `~/.config/fish/conf.d/aliases.fish`.
  Fish má **nativní autoload** (cokoliv v `conf.d/*.fish` se sourcuje samo, abecedně) — žádný
  loader netřeba, na rozdíl od bashe.
- **bash + zsh (sdílené, IMPLEMENTOVÁNO a ověřeno 2026-08-01, včetně jedné opravené vlastní
  chyby)**: `alias`/`export` syntaxe je mezi nimi bajtově identická (viz sekce 1) → jeden
  renderovaný výstup (`dot_bashrc.d/50-aliases-generated.sh.tmpl`), ne dva.
  **Korekce oproti původnímu návrhu č. 1:** adresář se `dot_bashrc.d` → `dot_shrc.d` NEPŘEJMENOVAL
  — dnešní bash setup vůbec nemá vlastní `dot_bashrc` (`~/.bashrc`), spoléhá na **Fedořin
  OS-default `~/.bashrc`**, který už sám sourcuje `~/.bashrc.d/*` (top-level, ne rekurzivně —
  proto existuje `00-loader.sh` pro personal/work podadresáře). Přejmenování by tenhle OS-default
  mechanismus potichu rozbilo. Řešení: `dot_bashrc.d` zůstává beze změny.
  **Korekce oproti původnímu návrhu č. 2 (vážnější, chycená vlastní chybou při testu):** první
  verze zsh podpory chtěla, aby chezmoi **plně vlastnil a přepisoval celý `~/.zshrc`** (nový
  `dot_zshrc` soubor). Při testu na REÁLNÉM `~/.zshrc` uživatele (ne v sandboxu) se ukázalo, že
  tam je kriticky důležitý obsah — Google Cloud SDK setup, proměnné pro Claude Code Vertex AI
  integraci, `SSH_AUTH_SOCK` pro Bitwarden SSH agenta — který by plné přepsání ztratilo. **Zsh
  má tedy přesně stejný vzor jako bash**, ne vlastnický: `~/.zshrc` zůstává uživatel/OS-vlastněný,
  jen dostane idempotentní append (`.chezmoiscripts/run_after_ensure-zshrc-sourcing.sh.tmpl`,
  stejný `run_` = běží při každém apply, stejná grep-a-případně-přidej logika jako u bashe) se
  sourcováním `~/.zshrc.d/*` — a teprve `~/.zshrc.d/` (nový, bezpečně plně chezmoi-vlastněný
  jmenný prostor, žádná kolize s existujícím obsahem) obsahuje vše ostatní:
  `00-shared.zsh` (explicitní seznam sdílených souborů z `~/.bashrc.d/` — ne slepý glob, protože
  bash-only soubory jako `99-prompt.sh` (PS1 escapes) a `80-functions-common.sh` (`export -f`,
  zsh to nemá) by zsh při startu shodily), `01-history.zsh` (zsh-native `SAVEHIST`/`setopt
  HIST_IGNORE_*` — bash `HISTCONTROL`/`HISTFILESIZE` nemá zsh obdobu, proto extra `01-bash-history.sh`
  vyňato ze sdíleného `exports` na bash straně), `99-prompt.zsh` (classic prompt, root=červená/
  user=zelená — **nejde sdílet** ani mezi bash a zsh, PS1 `\u`/`\h`/`\[...\]` vs. zsh
  `%n`/`%m`/`%{...%}`, ale `$FG_*` proměnné z `00-colors.sh` JSOU sdílené), `99-starship-init.zsh`
  (řadí se abecedně za `99-prompt.zsh`, takže starship legitimně přebíjí classic prompt).
  **Reálně odchycená chyba č. 3 (menší, na živém zsh):** prázdný `dot_bashrc.d/work/` adresář
  způsobil v zsh (na rozdíl od bash) fatální `no matches found` a potichu přerušil zbytek
  skriptu (prompt i starship init se vůbec nespustily) — zsh je na rozdíl od bash striktní na
  globy bez shody. Oprava: `(N)` glob kvalifikátor na obou dotčených smyčkách.
  Ověřeno po všech opravách: existující `~/.zshrc` obsah zůstává bajtově nedotčený (ověřeno
  `diff` proti záloze), nová funkcionalita (aliasy/PROMPT/starship layering) funguje identicky
  pro bash i zsh na reálných binárkách (macOS zsh 5.9, Homebrew bash), idempotence ověřena
  opakovaným spuštěním. Pokud se v budoucnu objeví další reálný rozdíl (env proměnné, sekce 4.2),
  řeší se jako explicitní per-shell výjimka v datech, ne rozdělením alias/export rendereru.

  **Migrace reálného obsahu uživatelova `~/.zshrc` (2026-08-01)** — přesně ten obsah, co odhalil
  chybu č. 2 výše, teď reálně přesunutý do datového modelu, rozdělený po funkcionalitě (na žádost
  uživatele) a per-profil zařazený:
  ```
  dot_zshrc.d/
    00-loader.zsh              # nový — personal/work podadresáře, zsh obdoba dot_bashrc.d/00-loader.sh
    10-path.zsh                # common — PATH += ~/.local/bin
    10-bitwarden-ssh-agent.zsh # common — SSH_AUTH_SOCK, jen macOS (Linux/Windows cesta jiná, zatím neřešeno)
    work/10-gcloud.zsh         # work-only — Google Cloud SDK shell integrace
    work/10-vertex-ai.zsh      # work-only — Claude Code Vertex AI proměnné (CLAUDE_CODE_USE_VERTEX, ...)
    personal/00-scaffold.zsh   # prázdný scaffold, žádný personal stroj zatím neexistuje
  ```
  Scope rozhodnutý s uživatelem: GCloud/Vertex → `work` (firemní GCP projekt, na budoucím
  personal Macu by nedávalo smysl), Bitwarden SSH agent → `common` (jedna desktop appka, sdílená
  mezi personal a work SSH klíči). `.chezmoiignore.tmpl` rozšířeno o `.zshrc.d/{personal,work}`
  masking (stejný vzor jako `.bashrc.d/{personal,work}`). Drobná oprava při migraci: originál měl
  natvrdo `/Users/zpolach/...` v cestách (uživatelské jméno zapečené) — nahrazeno `$HOME` pro
  přenositelnost na jiný účet/stroj. Ověřeno: work profil dostane gcloud+vertex navíc, personal
  profil je nedostane (jen common + scaffold), a funkčně vše (aliasy, Vertex proměnné, SSH socket
  s korektně dosazeným `$HOME`, PATH, prompt) běží správně v reálném zsh.
- **PowerShell 7 — IMPLEMENTOVÁNO a ověřeno (2026-08-07), živě na `winlab.local` (revertibilní
  UTM lab VM, viz §8), cíleno výhradně na `pwsh` (PS 5.1 kompatibilita je nanejvýš bonus, ne
  cíl).** Původní návrh počítal se **statickým, plně chezmoi-vlastněným `$PROFILE`** — stejná
  chyba jako u zsh/SSH/gitu (§2.1/§2.3/§2.4). Oprava: `$PROFILE` (konkrétně `CurrentUserCurrentHost`
  — PowerShell má 4 varianty `$PROFILE`, holá proměnná ukazuje jen na tuhle jednu) zůstává
  user/OS-vlastněný, `.chezmoiscripts/run_after_ensure-powershell-profile-sourcing.ps1.tmpl`
  (POZOR: `.ps1.tmpl`, ne `.sh.tmpl` — bash na nativním Windows neběží) idempotentně připíše
  dot-source blok mířící na `Documents/PowerShell/dotfiles.d/` (nový, plně chezmoi-vlastněný).
  `.ps1`/`.ps1.tmpl` nepotřebuje žádnou extra chezmoi konfiguraci — vestavěný default interpreter
  je `pwsh -NoLogo -File` (ověřeno oficiální dokumentací, `.tmpl` se ořízne jako první).

  **Renderer vzor — vždy `function jméno { příkaz @args }`, nikdy `Set-Alias`** (Set-Alias neumí
  navázat pevné argumenty, a skoro každý alias je "příkaz + vložené flagy").

  **Tři reálné, živě odchycené chyby, žádná nebyla zjevná dopředu:**
  1. **`-` (cd -) nejde vůbec naportovat** — PowerShell parser bere holé `-` vždy jako unární
     minus, i funkci doslova pojmenovanou `-` lze zavolat jen přes `& "-"`, nikdy jako typed
     input na promptu. `windows: skip`, stejná kategorie jako `sudo`/`path` (§3.6).
  2. **`(Get-ChildItem ...).Count @args` je syntax error, který shodí CELÝ vygenerovaný soubor**
     (parser error na jednom function bloku znemožní dot-source čehokoliv v souboru) — auto-append
     `@args` je bezpečné jen po skutečném cmdlet volání, ne po bare property-access výrazu. Oprava
     (`count`): `... | Select-Object -ExpandProperty Count` místo `.Count`.
  3. **`function ping { ping -n 5 @args }` způsobí nekonečnou rekurzi** — PowerShell function
     names mají přednost před externími příkazy stejného jména (na rozdíl od bash `alias`, který
     má vestavěnou jednoúrovňovou ochranu proti tomuhle přesně proto, aby šlo psát
     `alias ping='ping -c 5'`). Reálně vyžralo CPU na `winlab.local`, dokud nebyl proces zabit.
     Oprava: `ping.exe` (explicitní `.exe` obchází function-name shadowing).
  4. **Plain function nepředává pipeline input automaticky** — `function grep { Select-String
     @args }` volané jako `x | grep pattern` spadne ("missing mandatory parameter Path"), protože
     `Select-String` uvnitř funkce nedostane nic z vnějšího pipeline bez explicitního `$input`.
     ALE `$input |` univerzálně pro každý alias by bylo ŠPATNĚ — ověřeno, že `$input | Get-ChildItem`
     s prázdným `$input` (žádný upstream pipe) potlačí veškerý výstup úplně. Řešení: nové
     explicitní YAML pole `pipes_stdin: true` (jen `grep`/`fgrep`/`egrep`), renderer podmíněně
     prepend `$input |` jen tam.

  **Reálné, ověřené PowerShell ekvivalenty pro dosavadní Unix-only aliasy** (§3.6/`.chezmoidata/aliases/common/*.yaml`,
  `windows:` klíč): `Get-ChildItem` (+ `-Force`/`-Directory`/`-Hidden`/`Sort-Object` varianty pro
  `ls` rodinu), `Select-String`/`-SimpleMatch` (grep/fgrep/egrep), `Get-FileHash -Algorithm SHA256`
  (sha), `Get-NetTCPConnection -State Listen` (ports — nahradilo dřívější `windows: skip`),
  `Get-Date -UFormat %V` (week, vrací správné ISO číslo), `ping.exe -n 5` (ping — `-n` ne `-c`,
  ověřeno že Windows `-c` tiše ignoruje a napinguje default 4×), `C:\Windows\System32\drivers\etc`
  (ee, reálný `/etc` analog), `Start-Process pwsh -Verb RunAs -ArgumentList ...` (makeme/makeroot
  přes `takeown /F` — UX se liší od sudo, vyskočí nové zvýšené UAC okno, ne inline prompt).

  Env proměnné (`.chezmoidata/env/common/pager.yaml`): `MANPAGER`/`LESS_TERMCAP_*` dostaly
  `windows: skip` (žádný `less`/man na Windows) — `EDITOR`/`LANG`/`LC_ALL`/`PYTHONIOENCODING`
  beze změny, OS-neutrální.

  Ověřeno end-to-end živě: append-skript idempotentní (2× spuštění = identický hash), nová
  `pwsh` session s `$PROFILE` obsahujícím jen náš append blok skutečně načte
  `dotfiles.d/{05-env,50-aliases}-generated.ps1` a aliasy/env fungují přesně jak mají
  (`ll`/`grep`/`count`/`sha`/`ping`/`ports`/`EDITOR` všechny otestované naživo).

Příklad renderované šablony (fish) — **implementováno a otestováno** (`.chezmoitemplates/resolve-os-value`
+ `dot_config/fish/conf.d/aliases.fish.tmpl`):
```gotemplate
{{- range $cat, $entries := .aliases.common.categories }}
{{- range $entries }}
{{- $cmd := includeTemplate "resolve-os-value" (dict "value" .command "os" $.chezmoi.os) | trim }}
{{- if ne $cmd "skip" }}
{{ if eq .kind "abbr" }}abbr -a {{ .name }} '{{ $cmd }}' --position command{{ else }}alias {{ .name }} '{{ $cmd }}'{{ end }}  # {{ .description }}
{{- end }}
{{- end }}
{{- end }}
```
"Vyřeš OS-specifickou hodnotu" logika (default+override+`skip`, sekce 3.2) se nepíše třikrát
(jednou na shell) — patří jako sdílený `.chezmoitemplates/resolve-os-value` partiál (input:
`dict "value" ... "os" ...`, volaný přes `includeTemplate`, ne přes `template` — ten v Go
šablonách nejde zachytit do proměnné), volaný ze všech tří shell rendererů. Poznámka:
sprig/chezmoi nemá `kindIsMap` — pro test "je hodnota mapa" se používá `kindIs "map" $value`.

**Rendering se děje jen při `chezmoi apply`/`update`, ne při každém otevření terminálu** —
výsledný nasazený soubor je čistý, netemplatovaný fish/bash/PowerShell soubor.

### 3.4 Generování dokumentace

**IMPLEMENTOVÁNO (2026-08-14).** `ALIASES.md` je teď **částečně** generovaný — bloky mezi
`<!-- GENERATED:aliases-doc-{aliases,env}:start/end -->` značkami se generují přímo z
`.chezmoidata/{aliases,env}/**/*.yaml` (kategorizace scope → kategorie → kind abbr/alias),
zbytek (úvodní próza, sekce bez YAML zdroje jako Power management nebo personal/zsh-only obsah)
zůstává ručně udržovaný mimo značky.

- `.chezmoitemplates/generate-aliases-doc-aliases`/`-env` — dva samostatné generátory (ne jeden),
  aby šly nezávisle vkládat do dvou různých míst v dokumentu bez zásahu do ruční prózy mezi nimi.
  Používají stejnou `resolve-os-value` logiku jako reálné per-shell renderery. Každý OS sloupec se
  vždy vypisuje zvlášť (i když jsou hodnoty identické) — víc řádků, ale mechanicky triviální a
  nikdy špatně.
- `edit-aliases-core` (viz 3.5) — `chezmoi -S <repo> execute-template` na oba generátory slouží
  zároveň jako validace (YAML syntax i chybějící povinná pole spadnou tady, ne až při reálném
  `chezmoi apply`), teprve pak se výsledek vloží do `ALIASES.md` přes `awk`-based marker-replace
  (stejná technika jako Windows SSH config inline-embed).
- Pre-commit hook pojistka (bod 2 v původním plánu) zůstává nepostavená — čeká na stejnou
  gitleaks/secrets infrastrukturu, kterou navrhuje `DAILY_WORKFLOW.md`.

`README.md` beze změny — jen odkazuje na `ALIASES.md`, obsah negeneruje.

### 3.5 Workflow pro přidání/úpravu aliasu

**Existující bug k opravě:** dnešní `dot_bashrc.d/personal/dev-shortcuts`/`ali` alias otvírá
**deployed** cestu (`~/.bashrc.d/git-aliases` — `git-aliases`/`chezmoi-aliases` přesunuty
2026-08-15 z `personal/` do sdíleného top-level scope, viz §3.6), ne dev repo — editace se
přepíše při dalším `chezmoi apply` (stejná past jako "two-repo mental model" u evaultu).

Nový mechanismus:
- **`edit-aliases-core <scope>`** — sdílený externí skript, stejný bezpečnostní vzor jako
  `edit-evault` (`--repo`/`$DOTFILES_REPO`/interaktivní prompt, odmítnutí zápisu do chezmoi
  source-path — viz existující `private_dot_local/bin/executable_edit-evault` jako referenční
  implementace). Otevře $EDITOR na správném YAML v dev repu → ověří validitu YAML po uložení →
  `chezmoi apply --dry-run --verbose --source <repo>` (zachytí i chybu v šabloně) → pokud OK,
  `chezmoi apply --source <repo>` naostro → na konci regeneruje `ALIASES.md`.
- **`edit-aliases`** — tenká shell funkce, napsaná ručně zvlášť pro bash a fish (nejde sdílet
  jako externí skript, protože potřebuje ovlivnit *volající* shell). Zavolá `edit-aliases-core`,
  a při úspěchu **re-sourcne jen změněný alias soubor** v aktuálním shellu (ne celý
  `exec $SHELL -l` — to by bylo zbytečně těžké a resetovalo by i jiný stav session).
- **Známé omezení**: editace scope druhého profilu (např. `work` z osobního stroje) jde
  commitnout/pushnout, ale nejde lokálně živě otestovat — `.chezmoiignore` ho na tomhle stroji
  vůbec nevyrenderuje. Test až na reálném druhém stroji nebo v UTM lab VM (viz sekce 8).

### 3.6 Migrace existujícího obsahu — poznámky z rozboru `dot_bashrc.d/*`

- Bashové idiomy bez přímého fish/PowerShell ekvivalentu → navrhnout zvlášť pro každý shell,
  nepřekládat mechanicky: `sudo='sudo '` trik (trailing space), `path` alias s bash parameter
  expansion (`${PATH//:/\n}`), detekce `ls --color` vs. `-G`, `history -a` před chezmoi
  restartem (`ch`/`chd` aliasy).
- Prompt/barvy → z velké části řeší **starship** (viz sekce 6), zbytek jen jednořádkový init.
- Skutečné funkce s logikou (`80-functions-common.sh`) → převést na samostatné POSIX shell
  skripty v `PATH` místo shell-built-in funkcí, aby je bash i fish volaly stejně jako externí
  příkaz — obchází problém syntaktické portability. `zpfn_systemd_service_exists` je Linux-only
  (systemd) — OS-gated, ne univerzální.
- Většina dnešního `dot_bashrc.d/personal/*` obsahu není fakticky personal-specifická. `git-aliases`
  a `chezmoi-aliases` přesunuty do sdíleného top-level `dot_bashrc.d/` **2026-08-15** (včetně
  zsh — doplněny do explicitního seznamu v `00-shared.zsh`, a odstranění hardcoded
  `CHZ_DEPLOYMENT_PROFILE="personal"` exportu z `chezmoi-aliases`, viz `ALIASES.md`). `home-paths`
  (kromě konkrétních cest) a `dev-shortcuts` zůstávají kandidáty, zatím nepřesunuty.
- Drobné nálezy k opravě: mrtvý řádek `LESS_TERMCAP_md="${yellow}"` v `dot_bashrc.d/exports`
  (nedefinovaná proměnná, přepsaná o dva řádky níž); duplicitní/překrývající se logika hledání
  nejnovějšího GitHub release existuje na dvou místech (`zpfn_get_github_project_latest_release_download_link`
  runtime bash funkce vs. nepoužitý `.chezmoitemplates/get-github-latest-verson`) — ponechat jen
  chezmoi-template verzi (viz sekce 7).

### 3.7 WSL2 specifika

WSL2 se nasazuje jako obyčejný `linux` OS bucket (žádná zvláštní chezmoi-time OS větev) —
existující `dot_bashrc.d/wsl2_ssh_agent_support` se sám runtime-detekuje přes `$WSL_DISTRO_NAME`
a na nativním Linuxu se tiše přeskočí, takže stejný obsah jde nasadit všude v `linux` bucketu.
Package management (dnf, protože WSL2 u uživatele běží jako RHEL klon) je beze změny stejné jako
nativní Linux.

**SSH agent bridge** (`npiperelay`+`socat` most na Windows `openssh-ssh-agent` pipe) potřebuje
nastavit `SSH_AUTH_SOCK` v *aktuálním* shellu → stejný hybridní vzor jako `edit-aliases` (sekce
3.5): těžká logika (detekce npiperelay, spuštění socat relay) do sdíleného externího skriptu
(`wsl2-ssh-agent-bridge`), tenký per-shell wrapper zachytí výstup:
- bash: `export SSH_AUTH_SOCK=$(wsl2-ssh-agent-bridge)`
- fish: `set -gx SSH_AUTH_SOCK (wsl2-ssh-agent-bridge)`

**Potvrzené WSL2 aliasy k přidání** (cross-platform OS-mapa, stejný vzor jako `command`/`value`):
```yaml
- name: pbcopy
  command:
    darwin: pbcopy                       # nativní
    linux: xclip -selection clipboard    # nebo wl-copy na Waylandu mimo WSL2
    windows: clip.exe                    # přes WSL2 interop (Windows binárky na PATH)
  description: Copy stdin to clipboard
- name: pbpaste
  command:
    darwin: pbpaste
    linux: xclip -selection clipboard -o
    windows: powershell.exe -command "Get-Clipboard"
  description: Print clipboard contents to stdout
```
`wslview` (z balíčku `wslu`) — potvrzeno chtít, obdoba `xdg-open`/macOS `open` pro WSL2, otevře
URL/soubor přes defaultní Windows aplikaci. Patří jako balíček (sekce 7) + případně alias
`open`/`xdg-open` → `wslview` na WSL2.

`explorer.exe .` alias — **přeskočeno**, uživatel používá Total Commander s přístupem přes
`\\wsl$`, takže tenhle konkrétní alias nepřidává hodnotu.

### 3.8 Model funkcí a skriptů

Přidáno 2026-08-01 na žádost uživatele — do budoucna chce sdílet oblíbené funkce/skripty napříč
podporovanými shelly se stejnou funkcionalitou. Na rozdíl od aliasů/env proměnných (prostá data,
mechanicky renderovatelná) je funkce **libovolná logika** — nejde ji generovat z YAML stejným
způsobem, ale platí stejný princip "jeden zdroj pravdy, kde to jde".

**Dvě kategorie, podle toho, jestli funkce potřebuje měnit stav VOLAJÍCÍHO shellu:**

1. **Bezstavové** (nemění cwd/env/aliasy volajícího shellu — jen počítají a vrací výstup).
   Implementace: **jeden samostatný POSIX shell skript v `PATH`** (`private_dot_local/bin/`),
   volaný identicky jako externí příkaz z bash/zsh/fish — žádný per-shell překlad.
   **PowerShell**: POSIX skript s shebangem nejde nativně spustit bez WSL/Git Bash. Potvrzeno
   uživatelem (2026-08-01): **PowerShell parita je best-effort/odložitelná**, ne tvrdý požadavek
   — PowerShell verze se píše zvlášť jen když je pro konkrétní funkci výslovně chtěná, ne
   automaticky pro každou novou funkci.
2. **Stavové** (potřebují `cd`, nastavit proměnnou, cokoliv co musí přežít v shellu i po návratu
   z funkce — např. budoucí `mkcd` = mkdir+cd). Externí skript tohle nemůže (běží v subshellu,
   změny zmizí s ním) → potřebují **tenký nativní wrapper v každém podporovaném shellu** (bash/zsh
   — sdílené, viz 3.3; fish zvlášť; PowerShell best-effort), který zavolá sdílený externí skript
   pro těžkou logiku a výsledek aplikuje ve svém vlastním kontextu (`cd`, `export`/`set -gx`).
   Stejný vzor jako už existující `edit-aliases`/`wsl2-ssh-agent-bridge` (sekce 3.5/3.7) — tohle
   není nový mechanismus, jen jeho zobecnění a pojmenování.
   **Potvrzeno uživatelem (2026-08-01): zatím žádný konkrétní stavový příklad není** — jde o
   připravenost do budoucna, ne o okamžitou implementaci.

**Registr/manifest** (`.chezmoidata/functions.yaml`, návrh): na rozdíl od aliasů negeneruje
funkční kód, slouží jen jako **evidence a podklad pro dokumentaci** (analogicky k `ALIASES.md`,
sekce 3.4) — jméno, popis, kategorie (stateless/stateful), a which shells mají implementaci
hotovou vs. chybí (`TODO`). Umožní časem zjistit "tahle funkce existuje v bash/zsh/fish, ale ne
v PowerShellu" bez procházení kódu. Konkrétní schéma se doladí až při první reálné migraci
(viz sekce 9, tenhle krok).

### 3.8.1 Revize `80-functions-common.sh` a 3-vrstvý model sdílených knihoven (2026-08-01)

Společná revize (uživatel + agent) 4 dnešních funkcí, plus obecnější otázka "jak řešit sdílené
knihovní kódy (logování, barvy, sudo wrapper) napříč bash/zsh/fish a standalone skripty" —
vyvolaná nálezem, že `private_dot_local/bin/executable_edit-evault` si dnes definuje **vlastní**
lokální `ok()/err()/warn()/info()/die()` místo použití existující `.chezmoitemplates/scripts-library`.

**Výsledek revize funkcí:**

| Funkce | Osud |
|---|---|
| `zpfn_get_github_project_latest_release_download_link` | logika → nová fce ve `scripts-library` (vrstva 1 níže) |
| `zpfn_get_github_project_latest_release_version_number` | zahodit |
| `zpfn_systemd_service_exists` | zahodit (nepoužívá se) |
| `color` | zůstává jako sdílená interaktivní funkce (vrstva 2 níže) |
| `zpfn_edit` | zahodit (nepoužívá se) |

**Ověřená fakta, na kterých stojí obecný model knihoven (ne jen dohad):**

1. `scripts-library` se dnes **nesourcuje za běhu** — vkládá se textově při `chezmoi apply` přes
   `{{ template "scripts-library" }}` (viz `.chezmoiscripts/run_after_ensure-zshrc-sourcing.sh.tmpl`)
   + decoy `true || source ...` řádek jen pro ShellCheck. Výsledný skript je jeden kompletní
   samostatný soubor — žádné riziko s pořadím deploy vs. použití.
2. `export -f` je v zsh **potvrzeně no-op/rozbité** (ověřeno: funkce exportovaná v jednom zsh
   procesu není vidět v child zsh procesu) — proto `dot_zshrc.d/00-shared.zsh` dodnes explicitně
   vylučovalo `80-functions-common.sh` ze sdíleného seznamu.
3. Bez `export -f` funguje `function name { ... }` v interaktivní zsh identicky jako v bashi
   (ověřeno na `color` i na funkcích s `local`/`[[`/`$@`).
4. `scripts-library` má `set -euo pipefail` — správné pro jednorázový skript, ale **nebezpečné
   při sourcování do interaktivního shellu** (jedna chyba by shell ukončila) — musí zůstat
   oddělené od knihovny sourcované do živého rc.
5. Fish umí sourcovat soubor s víc `function...end` bloky, ale jeho idiomatický model je
   autoload `functions/*.fish` (jeden soubor = jedna funkce); syntax je s bash/zsh nekompatibilní
   — stejný závěr jako u PS1/`fish_prompt` (nejde sdílet kód, jen záměr).
6. `color` byl dnes mrtvý kód — `00-colors.sh` už definuje statické `$FG_*`/`$BG_*` proměnné,
   které prompty používají přímo.

**Model — 3 vrstvy:**

- **Vrstva 1 — build/skriptová knihovna** (`.chezmoitemplates/scripts-library`, bash, přísné
  `set -euo pipefail`): pro cokoliv běžící jako jednorázový subproces — dnešní `run_*.tmpl`
  provisioning skripty **a nově i standalone PATH skripty** (`edit-evault`-like, přejmenované na
  `.tmpl` a použijící stejný `{{ template "scripts-library" }}` vzor). Volající shell je
  irelevantní (bash/zsh/fish spouští jako externí příkaz) — skutečné sdílení napříč shelly.
  Rozšířeno o `github_release_asset_url()` (z revidované funkce výše), `log_ok()`, `log_warn()`
  (chyběly, `edit-evault` je potřeboval 1:1 náhradou za svůj lokální blok).
- **Vrstva 2 — interaktivní bash+zsh knihovna** (`dot_bashrc.d/80-functions-common.sh`,
  přepsaný — jen `color`, bez `export -f`): bash autoload beze změny, nově i v kurátorovaném
  seznamu `dot_zshrc.d/00-shared.zsh`. Nikdy netemplatovaná přes `scripts-library`, nesmí
  obsahovat `set -e`/`pipefail`.
- **Vrstva 3 — fish-native funkce**: žádné sdílení kódu možné. Budoucí fishový ekvivalent (např.
  `color`) by šel jako `dot_config/fish/functions/color.fish`, stejné jméno/rozhraní, oddělená
  implementace. Neimplementováno — dnes nic ve fish nepotřebuje.

**IMPLEMENTOVÁNO a ověřeno (2026-08-01):** vrstvy 1+2 hotové podle výše uvedeného modelu.
Nalezen a opraven i vedlejší bug při testování: `edit-evault`'s `${PROFILE^^}` (bash 4+ case
conversion) padalo na macOS systémovém `/usr/bin/env bash` (3.2.57, žádná novější bash v PATH)
chybou "bad substitution" — nahrazeno `tr '[:lower:]' '[:upper:]'` (funguje všude). Ověřeno:
`bash -n`/reálné spuštění všech chybových větví `edit-evault.tmpl` (chybí ejson/age lokálně, dál
netestováno — reálný decrypt→edit→encrypt cyklus čeká na §8 secrets), `color` sourcovaný v reálné
bash i zsh identicky, sandboxový `chezmoi apply --exclude=scripts` (plný, ne jen tento krok) čistý.

---

## 4. Datový model: env proměnné

### 4.1 Schéma

Analogické aliasům (stejné `.chezmoidata` chování, stejné `categories:`/scope/OS-mapa/`skip`
pravidlo), s rozšířením o **secret hodnoty z evaultu**:

```yaml
# .chezmoidata/env/common/editor.yaml — plain hodnota, OS-specifická
env:
  common:
    categories:
      editor:
        - name: EDITOR
          value:
            darwin: zed
            linux: nano
            windows: notepad
          description: Default editor

# .chezmoidata/env/work/tokens.yaml — soubor NENÍ tajný, jen odkazuje na klíč v evaultu
env:
  work:
    categories:
      tokens:
        - name: GITHUB_TOKEN
          secret: true
          evault_key: github_token   # skutečná hodnota se vytáhne z secrets/work/evault při apply
          description: GitHub API token for work org
```

`value` = prostý řetězec nebo OS-mapa (stejná pravidla jako `command` u aliasů). `secret: true`
položky `value` nepoužívají — renderer zavolá `output "ejson" "decrypt" ...` na příslušný evault
a vytáhne `evault_key`.

### 4.2 Renderery a první use-case pro evault-injection

`export X=Y` (bash) / `set -gx X Y` (fish) / `$env:X = "Y"` (PowerShell). Bashové koncepty bez
fish ekvivalentu (`HISTCONTROL`, `HISTIGNORE`) potřebují per-shell mapovací výjimku, ne
generování.

**Důležité pro pořadí implementace:** secret injekce z evaultu (`secret: true`/`evault_key`) je
**nový, dosud nikde v repu nepoužitý mechanismus** — dnešní kód jen odemyká EJSON klíč na disk
(`run_once_before_init_age.sh.tmpl`), ale žádný template z něj zatím netahá hodnotu. Implementovat
a otestovat **odděleně** od plain env proměnných (nejdřív ověřit plain pipeline, pak přidat
secret variantu jako izolovaný krok).

**IMPLEMENTOVÁNO a ověřeno (2026-08-01) — jen plain větev, secret injekce zatím ne** (§4.2 výše
schválně odděluje pořadí; blokováno navíc tím, že `ejson`/`age` nejsou na tomto stroji vůbec
nainstalované). Migrace reálného `dot_bashrc.d/exports` do `.chezmoidata/env/common/{editor,locale,pager}.yaml`
+ `dot_bashrc.d/05-env-generated.sh.tmpl` (bash+zsh, sdílené, `export X=$'val'`) +
`dot_config/fish/conf.d/env.fish.tmpl` (`set -gx X (printf 'val')`) — stejný `resolve-os-value`
partiál jako aliasy (§3.2). Původní soubor smazán, nahrazen v `dot_zshrc.d/00-shared.zsh`.
**Nález:** `LESS_TERMCAP_*` hodnoty používaly `\E` (velké, bashová ANSI-C quoting zkratka pro ESC)
— funguje v bash/zsh `$'...'`, ale **ne** v `printf` (ani bash, ani fish) - "\E" se propíše
doslovně. Sjednoceno na malé `\e` (funguje všude: bash/zsh `$'...'` i `printf`). Ověřeno: rendering
přes `chezmoi execute-template`, funkční test ve všech 3 shellech (`od -c` potvrdil identický ESC
byte `033` všude), plný sandboxový `chezmoi apply --exclude=scripts` (skripty vynechány kvůli
interaktivnímu Age passphrase promptu v `run_once_before_init_age.sh.tmpl`, který v neinteraktivním
sandboxu zůstal viset — reálný blocker pro §8, ne bug v tomhle kroku).

**Secret injekce z evaultu — IMPLEMENTOVÁNO a živě ověřeno (2026-08-14).** První reálný
konzument: git identity (`dot_config/private_git/{personal,work}/{common,hosts/github}
.gitconfig.tmpl`, viz uživatelský požadavek "chci mít firemní i GitHub noreply email v evaultu" —
mimo původní env-proměnné use-case z §4.1/4.2 výše, ale stejný mechanismus). Nový sdílený
`.chezmoitemplates/evault-field` (dict `{profile, path, sourceDir, keysDir}` → dešifrovaná
hodnota): `output "ejson" "-keydir" <keysDir> "decrypt" <evault>` (POZOR na pořadí — `-keydir` je
GLOBAL flag u `ejson`, musí být PŘED subpříkazem `decrypt`, ne za ním) + `fromJson` + procházení
tečkami odděleného `path`. `sourceDir`/`keysDir` se předávají explicitně v dictu, ne přes `$` —
`includeTemplate` přenastaví `$` na dict argument, takže `$.chezmoi.sourceDir` uvnitř partialu
selže s "map has no entry for key chezmoi" (na rozdíl od nativní `{{ template }}` akce, kde `$`
zůstává svázané s kořenovými daty celého volání).

Fail-fast ověřeno na obou úrovních: (1) chybějící EJSON klíč → `ejson decrypt` selže, chyba se
propaguje přes `output`; (2) chybějící/překlepnuté pole v `path` → **bez extra kódu by Go
template `index` na chybějící klíč mapy tiše vrátil nil** (`<no value>`, exit 0) — živě ověřeno,
opraveno explicitní `hasKey` kontrolou v každém kroku průchodu s `fail` a čitelnou chybovou
hláškou (`walked: git.foo`, ne jen "chyba někde").

Evault schéma (`git.user`/`git.email`/`git.github_email`) živě odladěno s uživatelem přes
`edit-evault` — cestou se objevily dvě samostatné drobnosti, obě opravené:
- `edit-evault` při neplatném JSONu dřív tvrdě skončilo a nechalo plaintext v `/tmp` bez cesty
  zpět — teď nabídne opětovné otevření editoru ve smyčce, dokud JSON není platný nebo uživatel
  výslovně neodmítne.
- Piktogramy v `scripts-library`/`bootstrap.sh`/`helpers/setup-encryption.sh` (`ℹ️`/`⚠️`/`⚠`/`✓`)
  používají buď variation selector (U+FE0F), nebo jsou samy o sobě Unicode
  East Asian Width=Ambiguous — terminály/fonty je vykreslují nekonzistentně (glyf široký, kurzor
  postoupí jen o 1 buňku → slití s dalším textem, přesně tohle uživatel viděl na screenshotu).
  Nahrazeno nativně širokými emoji bez ambiguity: `log_info`→🔵, `log_ok`→✅, `log_warn`→🔶
  (barva změněna ze žluté na oranžovou, sladěno s ikonou), `log_manual_action`→🔴 (kruh, pár k
  🔵, odlišný od kosočtverce `log_warn`).

`personal` profil má stejnou strukturu (`git.user`/`git.email`/`git.github_email`), ale jeho
EJSON klíč není na vývojovém stroji odemčený (žádný personal stroj zatím neexistuje, §1) —
šablony jsou hotové a syntakticky ověřené, ale ne živě protestované na reálných personal datech.

---

## 5. Editor config (nano/vim)

Žádné secrets, plně sdílené `common` napříč personal/work — potvrzeno, žádná speciální struktura
navíc potřeba teď. `$EDITOR` proměnná je pokrytá modelem env proměnných (sekce 4). Konkrétní
`.nanorc` obsah lze řešit jako prostý `dot_config/nano/nanorc` bez scope-splitu.

**Zed** (zvažovaný editor) pravděpodobně časem přinese potřebu scope-splitu i secrets (cloud/AI
funkce, telemetrie, firemní politika) — neřešit teď, řešit až při reálném nasazení.

---

## 6. Ghostty a starship

- **Starship** řeší prompt napříč shelly sám (podporuje bash/fish/PowerShell nativně), ale
  **nenahrazuje** klasický nativní prompt/color mechanismus (viz korekce v sekci 1) — ten zůstává
  univerzálně nasazený všude jako baseline, starship se navíc přidá tam, kde je nainstalovaný a
  přirozeně ho vrstevnatě přebije (jednořádkový init `starship init fish | source` na konci rc
  souboru, po klasickém `PS1`/`fish_prompt` nastavení).
  **PowerShell — IMPLEMENTOVÁNO a ověřeno živě (2026-08-07, winlab.local, `winget install
  --id Starship.Starship`):** `Documents/PowerShell/dotfiles.d/99-starship-init.ps1` (statický,
  ne `.tmpl` — obsah se neliší podle profilu/OS), stejný "if nainstalovaný" guard jako
  zsh/fish (`Get-Command starship -ErrorAction SilentlyContinue`). Syntax je jiná než
  bash/zsh/fish — `starship init powershell` vrací multi-line funkci, potřebuje `| Out-String |
  Invoke-Expression`, ne prosté `eval`/`source`. Ověřeno reálným barevným promptem
  (`Administrator in winlab in ~`).
  **Bonusem přidáno na žádost uživatele — fish-like autosuggestions přes PSReadLine**
  (`90-psreadline.ps1`, `Set-PSReadLineOption -PredictionSource History -PredictionViewStyle
  ListView` — PSReadLine je součástí PowerShellu 7, nic navíc netřeba instalovat, ověřena verze
  2.4.5 na winlab.local). **Reálný nález:** volání bez ochrany spadne chybou "predictive
  suggestion feature cannot be enabled" kdykoliv `$PROFILE` běží mimo skutečnou konzoli (např.
  skript, co `$PROFILE` jen dot-sourcne s přesměrovaným výstupem) — ověřeno přes
  `[Console]::IsOutputRedirected`, guard `if (-not [Console]::IsOutputRedirected) { ... }` to
  řeší, aniž by to shodilo zbytek profilu.
- **Ghostty (ověřeno, IMPLEMENTOVÁNO a ověřeno proti reálnému Ghostty binárnímu 2026-08-01)**:
  nativní include — `config-file = ?cesta` (`?` prefix = tichý no-op, když soubor chybí — podobné
  gitu). Pozdější `config-file` přepisuje dřívější hodnoty → common → profil → profil+OS, stejný
  směr jako git — **ověřeno reálně** (`ghostty +show-config --changes-only` s `XDG_CONFIG_HOME`
  nasměrovaným na testovací composed config: `font-size` nastavený na 13/14/15 ve
  common/work-common/work-mac vrstvě se korektně vyřešil na `15`). `ghostty +validate-config
  --config-file=...` prošel bez chyby i s částí fragmentů fyzicky chybějících (masknuté profily/OS
  přes `.chezmoiignore`) — `?` prefix je skutečně tichý, přesně jak dokumentace slibuje. Kruhové
  `config-file` odkazy = chyba (nehrozí, pokud fragmenty needlují jinam). **Běží jen Mac + Linux,
  žádný Windows** — Windows větev se pro Ghostty vůbec neřeší (ne "skip", prostě neexistuje).
  **Navíc podmíněno `has_gui: true`** (viz sekce 1) — na headless dev stroji (uživatel má reálně
  takový) se Ghostty vůbec neinstaluje ani nekonfiguruje, i kdyby role/OS jinak seděly — **ověřeno**
  (`has_gui: false` → `.config/ghostty` se vůbec nevytvoří). Instalace na Fedoře jde jen přes COPR
  (ověřeno — `scottames/ghostty`, oficiálně odkazovaný v Ghostty dokumentaci), ne přes default
  dnf repo — balíčkový model (sekce 7, zatím nepostavený) pro něj potřebuje speciální krok (`dnf
  copr enable` před `dnf install`), ne jen prosté jméno balíčku.

  Skutečná implementovaná struktura (`private_` atribut na konkrétním podadresáři, ne na celém
  `.config` — dávat `private_` na `.config` samotné koliduje s `dot_config/fish`, který na stejný
  cíl míří bez `private_`, chezmoi to odmítne jako "inconsistent state"):
  ```
  dot_config/private_ghostty/config          # statický, config-file řádky common→profil→profil+OS
  dot_config/private_ghostty/
    common.conf
    personal/{common,linux,mac}.conf
    work/{common,linux,mac}.conf             # work/mac.conf = reálně používaný stroj
  ```
  Maskování per profil/OS/`has_gui` je v `.chezmoiignore.tmpl` (cílové cesty, ne zdrojové —
  `private_` prefix zmizí v cílové cestě).
- **Starship (ověřeno, IMPLEMENTOVÁNO a ověřeno proti reálnému starship binárnímu 2026-08-01)**:
  **žádný nativní include** (multi-file podpora je zatím jen otevřený PR #6894, ne stabilní
  release). `STARSHIP_CONFIG` env proměnná existuje na přesměrování na jiný soubor, ale je to
  zbytečná oklika — starship zůstává na defaultní cestě `~/.config/starship.toml`, obsah je
  složený **template-kompozicí** (sekce 2.5): `dot_config/starship.toml.tmpl` volá
  `.chezmoitemplates/starship-common` + `starship-{personal,work}` podle `.deployment.profile`
  (na rozdíl od Ghostty tu není potřeba `.chezmoiignore` maskování — je to jeden renderovaný
  soubor, ne fyzicky přítomné/nepřítomné fragmenty). **Nasazeno univerzálně, bez `has_gui`/role
  podmínky** — potvrzeno v sekci 1: aliasy/env/fish/starship jsou čistě shell-úrovňové, fungují
  stejně přes SSH/konzoli jako v GUI terminálu. Iniciace je tenký `dot_config/fish/conf.d/starship-init.fish`
  (`if command -q starship; starship init fish | source; end`) — vrství se NAD klasický prompt,
  aktivuje se jen když je starship reálně nainstalovaný (balíčkový model, sekce 7, zatím
  nepostavený pro Linux/Windows — `dnf`/`apt` nemají starship v default repu).
- **Požadavek: root=červená, user=zelená i přes SSH na vzdálené (dotfiles-spravované) stroje**
  (1:1 náhrada dnešního ručně psaného `dot_bashrc.d/99-prompt.sh` `PS1` triku). Funguje, protože
  vzdálený stroj má nasazený **stejný** koncept (fish/starship config), ne kvůli SSH-specifickému
  mechanismu — SSH sem nic zvláštního nepřidává. Starship (ověřeno) má pro tohle nativní
  `username` modul s `style_user`/`style_root` poli:
  ```toml
  [username]
  style_user = "bold green"
  style_root = "bold red"
  format = "[$user]($style)@"
  show_always = true
  ```
  **Záludnost prověřena naživo (2026-08-01) a UKÁZALO SE, ŽE PRO FISH NEEXISTUJE** — žádný
  `exec $SHELL` fix není potřeba. Test na reálném čerstvém Linux lab VM: `starship prompt` jako
  normální uživatel → `\033[1;32m` (zelená), stejný příkaz jako root (`sudo ... starship prompt`)
  → `\033[1;31m` (červená), okamžitě a bez zpoždění. Přesněji reprodukován i **skutečný
  "uprostřed session" scénář**: v běžící interaktivní fish session spuštěn `sudo fish` (nová
  vnořená fish jako root, potomek téhož procesu) — prompt v ní byl červený hned na první
  vykreslení, žádná zpožděná/cachovaná zelená. Vysvětlení: starship je vždy spouštěný jako čerstvý
  subprocess při každém vykreslení promptu (přes `fish_prompt` hook nastavený `starship init
  fish`), takže tu není co cachovat — komunitní reporty o "cache bugu" se zjevně týkají jiné
  kombinace shellu/starship verze, ne fish + starship 1.26.0. `alias root='sudo -i'`
  (`50-aliases-power.sh`, zatím nemigrovaný do nového datového modelu) nepotřebuje žádnou úpravu.

---

## 7. Model instalace nástrojů/balíčků

**IMPLEMENTOVÁNO a živě ověřeno 2026-08-07** (jádro + COPR, bez GitHub-release fallbacku — viz
"Odloženo" níže). `.chezmoidata/packages.yaml` je teď "tool-first": jeden seznam nástrojů s
per-manager výjimkami místo dřívějších duplicitních `dnf.common`/`apt.common` seznamů. Skutečný
soubor je autoritativní zdroj pravdy pro přesné schéma; tahle sekce shrnuje DESIGN a co bylo
živě ověřeno, ne kopíruje celý YAML.

**Dva reálné, dřív neobjevené bugy nalezeny a opraveny při implementaci** (oba by tiše rozbily
instalaci balíčků, ne jen tuhle sekci):

1. **`run_onchange_install-packages.sh.tmpl` nikdy reálně nevolal `dnf install`** — jen spočítal
   `missing_packages` pole a vypsal ho do logu. Beze změny od doby, kdy skript vznikl. Opraveno
   přidáním reálného `sudo dnf -y install`/`apt-get -y install`/`brew install` volání.
2. **`is_dnf_package_installed` je na dnf5 nespolehlivá** (ověřeno živě na Fedoře 44/dnf5 5.4.2.1
   — `LinLab SSH`): `dnf list installed <pkg>` pro balíček, který NENÍ nainstalovaný, ale existuje
   v nějakém povoleném repu (typicky čerstvě COPR-enabled), vypíše "Available packages" a přesto
   vrátí exit 0 — takže se tichcky hlásil jako "už nainstalováno" úplně cokoliv dostupného v repu.
   Objevilo se to až teď, protože oprava bugu č. 1 poprvé opravdu zkusila balíček nainstalovat.
   Opraveno přechodem na `rpm -q <pkg>` (dotaz přímo do lokální RPM databáze, bez repo metadat).

**Windows — samostatný `.ps1.tmpl` skript, ne větev v bash skriptu.** Zásadní zjištění (ověřeno
živě na `winlab.local`, reálný `chezmoi apply` bez `--exclude=scripts`): `.sh` nemá na Windows
žádný default interpreter (chezmoi dokumentace — tabulka default interpreterů zná jen
`.ps1`/`.py`/`.rb`/`.pl`/`.nu`) a Windows neumí `.sh` spustit nativně. Chezmoi skript nespustí,
pokud se vyrenderuje na prázdný/whitespace-only obsah — ale dřívější `run_onchange_install-
packages.sh.tmpl` na Windows prázdný nebyl (`missing_packages=()`, `echo`, časomíra mimo `if dnf`
blok). Reálný test to potvrdil: `chezmoi: fork/exec ...: %1 is not a valid Win32 application`,
celý `chezmoi apply` skončil s chybou. **Stejný problém měly i všechny ostatní `.chezmoiscripts/
*.sh.tmpl` skripty** (bashrc/gitconfig/sshconfig/zshrc-sourcing, `init_age`, `after_user-
settings`) — žádný z nich dřív neměl OS guard. Oprava: **celé tělo** každého z nich (včetně
shebangu, ne jen kód pod ním) je teď obalené `{{- if ne .chezmoi.os "windows" -}} ... {{- end -}}`,
takže se na Windows vyrenderují na 0 bajtů a chezmoi je přeskočí. Nová
`.chezmoiscripts/run_onchange_install-packages.ps1.tmpl` (opačný guard, `eq .chezmoi.os
"windows"`) řeší winget instalaci nativně v PowerShellu — sdílí `resolve-package-entry`/
`render-winget-install` partials se sdílenou `.chezmoidata/packages.yaml` daty, jen jiný cílový
jazyk/syntaxe. **Vedlejší dopad**: git-config-includes a ssh-config-sourcing teď na Windows
NEDĚLAJÍ VŮBEC NIC (dřív by spadly, teď se jen tiše přeskočí) — funkční PowerShell ekvivalent pro
tyhle dva zůstává odložený navazující krok, viz "Odloženo" níže.

**Design (jak je implementováno):**
- `dnf`/`apt`/`brew` klíč na položce chybí → default = `name`. `winget` vždy potřebuje explicitní
  hodnotu (string ID nebo mapa) — chybí-li, bere se jako `skip` (žádný smysluplný default k
  odvození z `name`).
- `skip` (stejné klíčové slovo jako u aliasů/env OS-map) = tenhle manager balíček nemá.
  Kombinace "skip všude mimo jeden manager" = nástroj čistě pro jednu platformu (např. Total
  Commander jen na Windows, Ghostty jen na Linux/macOS) — žádný speciální mechanismus navíc,
  jen dvě samostatné položky.
- `roles: [...]` (`workstation`/`server`) — instaluje se jen když `.deployment.role` je v
  seznamu; chybí-li pole, default je "vždy" (`[workstation, server]`). **`role` je tímhle krokem
  poprvé reálně konzumovaná** (dřív jen resolvnutá a uložená, nikde nečtená — viz sekce 1/2.1).
- `requires_gui: true` (default `false`) — nezávislý filtr na `.deployment.has_gui`.
- `vm_types: [...]` — generalizace dřívějších top-level `virtualbox`/`vmware` klíčů; instaluje se
  jen na daném `.deployment.vm_type`. Stejný mechanismus, jen pole na položce místo zvláštní
  kategorie.
- `copr: <owner>/<repo>` (jen dnf) — před instalací `dnf copr enable -y <repo>`. Živě ověřeno
  (Ghostty na Fedoře, COPR `scottames/ghostty` — dnf/apt/brew casky totiž pro Ghostty defaultní
  repo/formuli nemají, resp. Fedora repo vůbec).
- `winget:` buď holý string ID, nebo mapa s `id` + libovolná kombinace `source`/`version`/
  `scope`/`architecture`/`installer_type`/`locale`/`location`/`custom`/`override`/`force`/
  `ignore_security_hash`/`skip_dependencies`/`allow_reboot`/`uninstall_previous` — plná tabulka
  mapování na `winget install` přepínače implementovaná v `.chezmoitemplates/render-winget-
  install`, i když dnes reálně používaná jen `installer_type`+`scope` (PowerShell 7 — MSIX se
  nezaregistruje jako `DefaultShell`/`defaultProfile`, potřeba `wix` MSI variantu). Globální/
  session flagy (`-e`, `--accept-*-agreements`, `--silent`, `--disable-interactivity`) jsou vždy
  součástí základního příkazu, ne YAML pole.
- **`brew install <name>` automaticky pozná cask vs. formuli** (ověřeno živě — `ghostty`/
  `bitwarden` jsou casky, `brew install ghostty` bez `--cask` je nainstaloval rovnou) a je
  idempotentní (exit 0 i při opakovaném volání na už nainstalovaný balíček). `brew list
  --versions` ale funguje jen pro formule, ne casky — `is_brew_package_installed` zkouší obojí
  (`brew list --versions` NEBO `brew list --cask --versions`).

**Živě ověřeno end-to-end** (klony `LinLab SSH`/`Maclab SSH`/šablony `WinLab Template`, smazané
po testu):
- **LinLab (dnf, Fedora 44/dnf5)**: `git`+`ghostty` (role `workstation`) reálně nainstalovány
  včetně COPR enable, `role: server` scénář správně vyprodukoval prázdný seznam (žádný dnf
  zásah), opakované spuštění správně nehlásilo nic k instalaci (idempotence).
- **Maclab (brew)**: `git`/`starship`/`bitwarden` (cask) nainstalovány, `ghostty` (už dřív
  nainstalovaný cask) správně přeskočen, idempotence potvrzena opakovaným spuštěním.
- **winlab (winget)**: reálný, plný `chezmoi apply` (BEZ `--exclude=scripts`) proběhl s exit 0 —
  žádný pád na `.sh.tmpl` skriptech. `Microsoft.PowerShell`/`Microsoft.WindowsTerminal` (na
  šabloně už předinstalované) správně detekovány a přeskočeny přes `winget list --id ... -e`,
  `Git.Git`/`Starship.Starship`/`Bitwarden.Bitwarden`/`Ghisler.TotalCommander` reálně
  nainstalovány.
- **apt**: žádný Debian/Ubuntu lab stroj v UTM knihovně neexistuje — jen `chezmoi
  execute-template` dry-run (syntakticky validní bash, `git` jako jediný non-skip nástroj v
  dnešním seznamu). Zdokumentováno jako známá mezera, ne blokující.

**Finální seznam nástrojů** (zúženo v diskuzi s uživatelem — `tio`/`keepassxc`/`doublecmd`/
`openssl` vypadly, buď obsolete pro uživatele nebo nahrazené platformově specifickým nástrojem):
`git` (jen workstation), `starship` (jen brew/winget, dnf/apt čeká na odložený GitHub-fallback),
`bitwarden` (náhrada za KeePassXC — GUI desktop klient, nezaměňovat s `bw` CLI ze sekce 10),
`powershell7` (záměrně jen Windows, i když `pwsh` je cross-platform — uživatelská volba), `ghostty`
(jen Linux/macOS), `windows-terminal` (jen Windows, náhrada za Ghostty tam — jen instalace,
`settings.json` config odložen), `totalcmd` (jen Windows, náhrada za Double Commander — uživatel
na Windows používá Total Commander).

**`bootstrap.sh` — obecný princip "preferuj brew, kde to jde" aplikovaný i na bootstrap
prerekvizity (2026-08-07).** Uživatelský požadavek: kdykoliv `bootstrap.sh` na macOS potřebuje
nějaký nástroj, a existuje pro něj funkční Homebrew formule, použít brew místo ručního stažení
binárky. Nový `bootstrap.sh` blok bootstrapuje **Homebrew samo o sobě** (macOS, pokud chybí,
stejný `NONINTERACTIVE=1` install skript jako `install-os-package`), hned po Xcode CLT sekci, aby
byl brew k dispozici i pro chezmoi/EJSON o kousek níž ve stejném skriptu. `chezmoi` teď na macOS
s dostupným brew instaluje přes `brew install chezmoi` (homebrew-core formule) místo
`get.chezmoi.io` skriptu. **EJSON** (Shopify) — ověřeno živě, `ejson` NENÍ v homebrew-core, ale
existuje oficiální tap `Shopify/homebrew-shopify` s funkční formulí (`brew tap shopify/shopify`
+ `brew install shopify/shopify/ejson`, verze 1.5.4, nainstalováno a otestováno) — použito místo
dosavadního ručního stažení GitHub release tarballu. Curl/wget tarball fallback zůstává pro
Linux (kde `ejson` v dnf/apt repu není) a jako záchranná síť, kdyby Homebrew bootstrap na macOS
selhal.

**Odloženo (samostatné navazující kroky, ne řešeno v tomhle):**
- **GitHub-release fallback** pro nástroje bez default repo balíčku (typicky `starship` na
  dnf/apt) — `.chezmoitemplates/get-github-latest-verson` helper existuje, ale není zapojený.
  `helpers/install-starship.sh` (legacy manuální skript) zůstává, dokud fallback nepřistane.
- **Windows Terminal `defaultProfile`/`settings.json` správa** — fragment (font-size, viz níže)
  je hotový, ale globální nastavení (nastavit dotfiles profil jako výchozí, keybindings) by
  vyžadovalo sáhnout na skutečný, MSIX-balený a JSONC `settings.json` — vědomě odloženo, viz níže.

**Git/SSH config na Windows — IMPLEMENTOVÁNO a živě ověřeno 2026-08-07** (navazující krok po
balíčkách výše). Nové `run_after_ensure-gitconfig-includes.ps1.tmpl` a `run_after_ensure-
sshconfig-sourcing.ps1.tmpl`, oba Windows-only (`eq .chezmoi.os "windows"` guard, opačný než
bash verze).

- **Git**: stejný mechanismus jako bash (`Ensure-IncludeBlock` = PowerShell obdoba
  `ensure_include_block`), stejné čtyři include/includeIf bloky, stejné sdílené fragmenty
  (`~/.config/git/...`) — git for Windows sám tilde-expanduje `path =` hodnoty a ctí `$HOME`
  (PowerShell 7 ho nastavuje automaticky), takže žádná změna obsahu, jen jiný interpreter okolo.
  Živě ověřeno: `git config --list --show-origin` na reálném Windows stroji ukázal všechny 4
  fragmenty správně napojené.
- **SSH — zásadně jiný mechanismus, ne přímý port.** Live testování (WinLab Template klon)
  odhalilo, že **`Include` v Win32-OpenSSH je reálně nefunkční** — systematicky otestováno
  (absolutní cesta se zpětným i dopředným lomítkem, s glob i explicitní jeden soubor, quoted i
  ne, tilde forma, cesta relativní ke config souboru): jakákoliv absolutní nebo tilde cesta
  **zavěsí `ssh.exe` na neurčito** (ne error — nekonečné čekání, potvrzeno i s `-G`), relativní
  cesta doběhne, ale fragment se **potichu vůbec nenačte**. Ověřeno na vestavěné
  `OpenSSH_for_Windows_9.5p2` I na nejnovější `10.0.0.0p2` (stažené přímo z GitHub release Win32-
  OpenSSH, ne přes `winget install Microsoft.OpenSSH.Preview` — ten mimochodem vůbec neobsahuje
  klientský `ssh.exe`, jen server-side komponenty) — je to tedy přetrvávající bug portu samotného,
  ne věc verze. Řešení: PowerShell skript při každém apply **přímo vloží/regeneruje obsah**
  `conf.d/*.conf` fragmentů jako sentinel-ohraničený blok (`# BEGIN/END dotfiles conf.d`) uvnitř
  `$HOME\.ssh\config` — žádný `Include`, jen stejná sdílená data jinou cestou. Blok se
  přegeneruje (ne jen ověří přítomnost) při každém apply, protože obsah fragmentů se může měnit.
  Živě ověřeno: `$HOME\.ssh\config` po apply obsahuje kompletní obsah všech fragmentů
  (`maclab`/`windev`/`*.redhat.com`/`Host *` common blok), idempotence potvrzena (2. apply beze
  změny hashe).
- Vedlejší nález nutný k SSH ověření: **`ssh -G <host>` samo o sobě zavěsí bez `-T` flagu**
  (pty/tty detekce se zasekne mimo skutečnou konzoli) — `-T -G` funguje okamžitě. Nesouvisí s
  Include bugem, ale bez týhle opravy nešlo Include vůbec testovat.

**Windows Terminal font-size fragment — IMPLEMENTOVÁNO a živě ověřeno 2026-08-07.** Windows
Terminal má nativní, dokumentovaný "fragment extension" mechanismus
(`%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\<app>\*.json`) — funguje bez ohledu na to,
že `winget install Microsoft.WindowsTerminal` instaluje MSIX balíček, protože je to obecná
cesta pro cizí přispěvatele, ne Windows Terminalu vlastní config. Nový chezmoi-spravovaný soubor
`AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/profile.json.tmpl` (masked stejně
jako Ghostty — `!has_gui` nebo ne-Windows) přidává jeden nový profil (`"name": "Dotfiles"`,
`pwsh.exe`) s vlastní, pevně danou GUID (`{1ae1727f-65b8-4645-b6d2-ee9d98d5c1d1}` — nikdy
neregenerovat, jinak by Windows Terminal viděl "nový" profil při každém apply) a jen
`font.size` (13 personal / 14 work) — stejný minimální rozsah jako dnešní Ghostty config (žádná
`font-family`/barevné schéma tam taky není). **Fragmenty jsou čistě aditivní** — kolize s
uživatelovými daty nejsou možné, dokud se nepoužije vlastní GUID (ne `"updates": "{cizí-guid}"`)
a jednoznačné jméno (žádné schéma zatím vůbec nedefinujeme). Živě ověřeno: `chezmoi apply`
nasadí validní JSON na správné místo, `.chezmoiignore.tmpl` maska funguje pro
`!has_gui`/ne-Windows kombinace.
**Vědomě odloženo** (rozhodnuto s uživatelem po diskuzi o rizicích): `defaultProfile` a jakékoliv
jiné globální nastavení by vyžadovalo sáhnout na skutečný `settings.json` — křehká MSIX cesta
(`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`,
jiná pro Preview kanál), navíc JSONC s komentáři (naivní `ConvertFrom-Json`/`ConvertTo-Json`
roundtrip by komentáře smazal a soubor přeformátoval), a `defaultProfile` je skalární hodnota,
kterou by automatický zápis přepsal bez zeptání (na rozdíl od čistě aditivních fragmentů/include
bloků všude jinde v tomhle repu). Uživatel by si dotfiles profil zatím vybíral ručně z dropdownu.

---

## 8. Testovací prostředí (UTM lab VM)

Lokální UTM (Mac) VM knihovna. `utmctl` (Homebrew) nativně podporuje
`clone`/`delete`/`start`/`stop`/`exec`/`file` (guest agent)/`ip-address`/`status`/`list` — plný
clone/test/discard cyklus i spouštění příkazů na hostu jde skriptovat bez GUI.

**Pravidlo (platí pro každý OS lab VM stejně):** jedna **read-only template VM** na OS, čistá,
SSH povolené. Nikdy nespouštět/needitovat/nemazat template samotnou ani žádnou jinou existující
VM bez výslovného svolení uživatele pokaždé znovu.

- **Mac**: `Maclab SSH` — potvrzený template. Připojení: `ssh tester@maclab.local` (mDNS
  hostname napevno v image — běžet by měla jen jedna instance najednou, ať nekoliduje resolving).
- **Linux**: `LinLab SSH` — potvrzený template (Fedora). Připojení: `ssh tester@linlab.local`.
  Fixní baseline VM: síť + SSH + sudo uživatel + `curl` — nic víc ručně předinstalované, zbytek
  (git, age, fish, starship, případně GUI+Ghostty) má nainstalovat samotný bootstrap/dotfiles,
  aby se tím reálně otestovala automatizace, ne obešla.
- **Explicitní svolení uživatele (2026-08-01):** smím používat `utmctl` na klonování obou
  templatů (`Maclab SSH`, `LinLab SSH`) a jejich klony libovolně upravovat/mazat/znovu vytvářet
  bez ptaní pokaždé znovu. Ostatní VM v UTM knihovně zůstávají zakázané bez domluvy s uživatelem.
- **Windows**: k dispozici existující VM (`Win11 Pure Naked Install`, `Win Devel VM`) s SSH
  přístupem — která z nich je sankcionovaný template a její přesné SSH spojení **nejsou zatím
  potvrzené uživatelem** — nepředpokládat, ptát se.

Pracovní cyklus (stejný pro každý OS, jakmile je template potvrzený): `utmctl clone "<template>"
--name <clone>` → testovat na klonu → `utmctl delete <clone>` → opakovat. Klony vytvořené sebou
samým (agentem) lze klonovat/mazat/znovu-klonovat autonomně (počkat, ověřit přes
`utmctl list`/`status`, že klon zmizel, pak nový clone) — šablonu ani cizí VM nikdy bez svolení.

**Záměr uživatele: stavět a testovat Mac a Linux paralelně**, ne sekvenčně (Linux odsunutý až
"na později"). Windows lab prostředí je k dispozici, ale zatím bez potvrzených detailů.

---

## 9. Pořadí implementace

Green-field POC, žádné reálné nasazení k ochraně — proto stavět rovnou k cíli, ne
"nejbezpečnější krok první":

1. **Základ**: zobecnění `.chezmoiignore` maskování (profile × OS × role) — sekce 2.1. Nosná
   konstrukce pro všechno ostatní.
2. **UTM lab VM** zprovoznit hned vedle (sekce 8) — bezpečné hřiště na testování, paralelně
   Mac + Linux.
3. **Fish aliasy/env jako první shell cíl** (ne bash) — sekce 3-4, paralelně na mac i linux.
4. **Ghostty config** (sekce 6, nativní include).
5. **Starship config** (sekce 6, template-kompozice).
6. **Bash+zsh (sdílené) a PowerShell renderery** — rozšíření stejné datové základny, až fish
   funguje. **Bash+zsh HOTOVO a ověřeno 2026-08-01** (viz sekce 3.3 pro detaily a korekci
   původního "přejmenovat na dot_shrc.d" nápadu). PowerShell zbývá.
7. **Funkce a skripty** (sekce 3.8) — migrace `80-functions-common.sh` na samostatné POSIX
   skripty v `PATH`, založení `.chezmoidata/functions.yaml` registru. Nezávislé na krocích 8-10,
   dá se udělat kdykoliv po kroku 6.
8. **Env proměnné se secrets** (evault injection, sekce 4.2) — izolovaný krok po ověření plain
   varianty.
9. **Git config, SSH config** (sekce 2.3, 2.4).
10. **Model instalace nástrojů/balíčků** (sekce 7) — nejvyšší riziko, až na konec. **HOTOVO a
    živě ověřeno 2026-08-07** (jádro + COPR; GitHub-release fallback a Windows Terminal config
    zůstávají odložené navazující kroky, viz sekce 7).
11. Editor config (Zed) a plný automatizovaný server bootstrap (secret manager pro headless
    servery) zůstávají **záměrně odložené** — viz sekce 10.

---

## 10. Explicitně odložené (neřešit v této fázi)

- **Plný automatizovaný/headless secret bootstrap pro servery.** Navržený budoucí směr: znovu
  použít self-hosted Bitwarden přes headless `bw login --apikey` + `bw unlock --raw`, zapojené
  jako další krok do "nainstaluj prerekvizity před sahnutím na secrets" vzoru v
  `run_once_before_init_age.sh.tmpl` (dnes tam `age`/`git`, přidat `bw`). Poznámka: `age decrypt
  --passphrase` čte heslo z řídicího terminálu záměrně (bezpečnostní vlastnost proti úniku přes
  historii/env/`ps`) — nejde nahradit jen přesměrováním vstupu, server-role větev to musí
  obcházet úplně jinou cestou (secret manager rovnou dodá odemčený klíč). URL Bitwarden serveru
  per profil se nesmí commitnout do repa (info leak o self-hosted infrastruktuře) — řešit jako
  `promptStringOnce` (lokální chezmoi config, nikdy v gitu) pro lidmi provisionované stroje, pro
  automatizované stroje dodat externě přes provisioning nástroj (Terraform var/cloud-init).
  Doporučeno scoping API klíče na úzkou BW kolekci jen pro server-bootstrap secrets, ne plný
  přístup k vaultu.
- **Editor config pro Zed** — až bude reálně nasazený.
- **PowerShell abbr-parita** (fish-like rozbalení po mezeře) — schéma (`kind` pole) je navržené
  tak, aby šlo přidat později jen výměnou/rozšířením PowerShell rendereru (přes PSReadLine custom
  key handler `Set-PSReadLineKeyHandler -Key Spacebar ...`), bez zásahu do datového modelu.

---

## 11. Ověření / jak testovat end-to-end

Pro každý krok z sekce 9, na příslušné UTM lab VM (sekce 8):
1. `utmctl clone "<template>" --name <test-clone>`, počkat na start, `ssh` na klon.
2. Na klonu: bootstrap podle `README.md`/`bootstrap.sh`, ověřit, že `chezmoi apply` proběhne
   bez chyby a `chezmoi apply --dry-run --verbose` je čistý.
3. Pro aliasy/env: otevřít nový shell (fish), ověřit že očekávané aliasy/abbr/env proměnné
   existují a mají správnou OS-specifickou hodnotu; zkusit `edit-aliases`, ověřit že se úprava
   projeví bez restartu shellu.
4. Pro git/ssh: ověřit `git config --list --show-origin` ukazuje očekávané hodnoty ze správných
   fragmentů; u SSH ověřit pořadí přes `ssh -G <host>` (ukáže efektivní resolvovanou konfiguraci).
5. Pro balíčky: ověřit, že `run_onchange_install-packages` nainstaluje jen role-relevantní sadu.
6. `utmctl delete <test-clone>` po ověření, počkat na zmizení ze `utmctl list`, opakovat pro
   další krok/OS.

Existující bezpečnostní vzor pro editaci (evault i aliasy): vždy v **dev repu**
(`~/Devel/dotfiles` nebo ekvivalent na jiném stroji), nikdy v chezmoi source-path
(`~/.local/share/chezmoi`) ani přímo v deployed `$HOME` — viz "Two-repo mental model" v
`DAILY_WORKFLOW.md` a bezpečnostní kontrola v `private_dot_local/bin/executable_edit-evault`.
