# Tmuxinator → smug: punkt powrotu do migracji

Stan sprawdzony: **2026-10-18**. Migrację odłożono; `mux` nadal uruchamia
Tmuxinatora. Smug nie został zainstalowany ani zastosowany w konfiguracji.
Nie planujemy utrzymywania własnego forka tylko na potrzeby tej migracji.

## Co ustaliliśmy

Pozostałe siedem konfiguracji projektów można przekonwertować na smug.
Nieaktualną konfigurację `cc-workers` usunięto osobno na prośbę użytkownika.
W przygotowanym wariancie wystarcza funkcja `mux` przekazująca argumenty do smug:

- `mux projekt` lub `mux start projekt` tworzy sesję albo wraca do istniejącej;
- `before_start` uruchamia przygotowanie, w tym `git sync`, tylko przy tworzeniu;
- odłączenie pozostawia sesję i procesy działające;
- `mux stop projekt` wykonuje hook stop, potem kończy sesję.

Użytkownik zwykle uruchamia `mux` z nowego terminala poza tmux. Nie korzysta
z przechodzenia między projektami przez `mux` wewnątrz istniejącej sesji.
To ogranicza znaczenie jednego z odtworzonych problemów. Migracja jest możliwa
dla tego sposobu pracy; nie stwierdziliśmy, że smug jest ogólnie nieużywalny.

Zysk z zamiany okazał się umiarkowany: Ruby nadal pozostaje potrzebne do innych
narzędzi i projektów. Na razie pozostajemy przy działającym Tmuxinatorze.

## Zachowanie, które wymaga ponownego sprawdzenia

Testowano **smug v0.3.19**, **tmux 3.6** i **Tmuxinator 3.4.2**.
W smug błąd `Start` powoduje bezwarunkowe wywołanie `Stop`. Dotyczy to również
błędu dołączania do już działającej sesji. `Stop` wykonuje hook cleanupu,
a po jego powodzeniu zabija sesję. Błąd samego hooka przerywa operację przed
zabiciem sesji.

Potwierdzono to zarówno w [kodzie wydania](https://github.com/ivaaaan/smug/blob/v0.3.19/main.go#L191-L197),
jak i testami rzeczywistego pliku wykonywalnego. Testy realnego tmux używały
unikalnych socketów i katalogu HOME w `/tmp`, pustej konfiguracji tmux,
powłoki `/bin/sh` i markera plikowego zamiast prawdziwego cleanupu.
Nie uruchamiano komend projektów ani kontenerów. Serwery testowe zakończono.

| Scenariusz | Wynik |
| --- | --- |
| Zwykły attach, potem detach | Kod 0; sesja pozostała; hook stop nie uruchomił się |
| Wywołanie smug z sesji na sockecie A do odłączonej sesji na sockecie B | `no current client`; hook stop uruchomiony; sesja B zabita; sesja A pozostała |
| Powrót do istniejącej sesji bez terminala TTY | `open terminal failed: not a terminal`; hook stop uruchomiony; sesja zabita |
| Nowy start z nieudaną komendą `before_start` | Hook stop uruchomiony mimo nieutworzenia nowej sesji |

Obecne projekty mają oddzielne sockety. Przypadek A → B ma więc zastosowanie
do ich topologii, choć nie odpowiada zwykłemu sposobowi pracy użytkownika.
Wariant migracji przenosi dotychczasowe hooki `on_project_exit` do `stop`,
dlatego rollback może uruchomić również zatrzymanie kontenerów Compose albo
serwera Rubocopa. To działanie jest szersze niż samo zamknięcie pustej sesji.

Nie sprawdzano utraty połączenia SSH ani zamknięcia okna terminala.
Nie należy utożsamiać tych sytuacji z przetestowanym zwykłym detach.

## Czy upstream już nad tym pracuje?

Stan pobrano bezpośrednio przez GitHub API 2026-10-18:

- [Otwarte PR-y](https://github.com/ivaaaan/smug/pulls): **0**.
- [Najnowsze wydanie](https://github.com/ivaaaan/smug/releases/tag/v0.3.19):
  **v0.3.19**, opublikowane **2026-06-30**.
- `master`: `8320fb4c24d10c6303d2d1254f7eee201a4e6b9f`;
  [porównanie z wydaniem](https://github.com/ivaaaan/smug/compare/v0.3.19...master)
  zwróciło `identical`, bez commitów przed ani za wydaniem.
- Przejrzano tytuły i treści wszystkich **151** rekordów issues/PR dostępnych
  w dwóch stronach API. Nie znaleziono dedykowanej poprawki ani zgłoszenia
  opisującego dokładnie niebezpieczny rollback po nieudanym attach.
  Nie przeszukiwano wszystkich komentarzy ani zewnętrznych forków.

Powiązane zmiany już są scalone i obecne w sprawdzonym wydaniu:

| PR | Zakres | Znaczenie dla migracji |
| --- | --- | --- |
| [#12 — Terminate session on fail](https://github.com/ivaaaan/smug/pull/12) | Dodał rollback w 2020 r. | Źródło obecnego zachowania, nie oczekująca poprawka |
| [#145 — attach config option](https://github.com/ivaaaan/smug/pull/145) | `attach: true`; scalony 2025-12-19 | Umożliwia konfigurację attach; nie zmienia rollbacku |
| [#152 — switch command](https://github.com/ivaaaan/smug/pull/152) | Alias `start -a`; scalony 2026-02-10 | Nie naprawia przełączania między osobnymi socketami ani rollbacku |
| [#153 — attach/detach hooks](https://github.com/ivaaaan/smug/pull/153) | Hooki klientów; scalony 2026-02-11 | Nie rozdziela jawnego stop od cleanupu po błędzie |

Nie ma obecnie konkretnego oczekującego PR-a, którego scalenie rozwiązałoby
nasze zastrzeżenia. Nie wysłano własnego issue ani PR-a.

## Jak wrócić do tematu

Przy kolejnym podejściu sprawdzić nowe wydanie i kod rollbacku, a następnie
powtórzyć cztery powyższe scenariusze na izolowanych sesjach. Szczególnie ważne:
błąd attach do istniejącej sesji powinien pozostawić ją działającą i nie wywołać
cleanupu projektu. To pożądana poprawa upstream, a nie opis obecnego smug.

Konwersja konfiguracji wymagała następujących dopasowań:

- `pre_window` przenosi się do `commands` każdego okna, zachowując przygotowanie
  powłoki przed właściwą komendą. Nie ma potrzeby dodatkowego launchera projektu.
- Socket wpisuje się pod `tmux_options.socket_name`, nie na głównym poziomie YAML.
  Zachowanie starych socketów i nazw sesji pozwala wracać do istniejących sesji.
  Dotychczasowy socket jednego projektu jest wyliczany z lokalizacji pliku ERB;
  jego wartość trzeba świadomie wyznaczyć na danej maszynie.
- Powtórzone nazwy okien trzeba rozróżnić: smug wybiera początkowe okno po nazwie.
- Smug rozwija zmienne środowiskowe przed parsowaniem YAML. Sprawdzanie funkcji
  zsh przez `$+functions` zastąpiono `typeset -f`, a KUBECONFIG przeniesiono do
  `env` sesji. Substytucja `$(pwd ...)` pozostała komendą dla powłoki panelu.
- Hooki wymagające zsh należy uruchamiać przez `zsh -l -c`; sam smug wykonuje
  hooki przez `/bin/sh`. Nie zmieniać przy tym kolejności ani warunków komend.
- Hooki `on_project_exit` miały przejść do `stop`, aby detach pozostawiał kontenery.
- `mux` pozostaje prostą funkcją przekazującą argumenty. Dla zsh przygotowano
  lokalne uzupełnianie nazw projektów; wydanie nie dostarcza completion zsh.
- Planowany backend mise: `github:ivaaaan/smug`, początkowo przypięty do
  sprawdzonej wersji. Usuwa się wpis `gem:tmuxinator`, pozostawiając pozostałe
  narzędzia Ruby. Instalacji przez mise jeszcze nie sprawdzono.

Prototyp przeszedł 42 scenariusze z atrapami tmux/hooków (6 dla każdego z 7
projektów), kontrolę składni zsh/TOML, callback completion, dry-run Stow i
`git apply --check`. Testy rzeczywistego tmux ujawniły opisany problem,
którego atrapa przełączania klienta nie modelowała. `make doctor` dla repo
również przeszedł. Nie testowano rzeczywistego uruchamiania aplikacji projektów.

Robocze pliki były w `/tmp/smug-migration/`: kandydat konfiguracji, dwa osobne
patche repozytoriów, harnessy i logi. To artefakty tymczasowe, które mogą zniknąć.
Ta notatka przechowuje ustalenia potrzebne do ponowienia prac; aktualne pliki
Tmuxinatora i `.zshrc` pozostają źródłem prawdy do nowej konwersji.

Zmiana prywatnych konfiguracji, commit w `prv/` oraz aktualizacja gitlinka
pozostają oddzielnymi krokami. Ta notatka nie oznacza zastosowania migracji.
