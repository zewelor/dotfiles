# Decision log inbox

Ten plik jest krótką kolejką nowych decyzji, a nie kroniką każdej naprawy.
Surowe wpisy historyczne i ich indeks znajdują się w
[`docs/decision_log/`](decision_log/).

## Co warto zapisywać

Dodawaj tylko decyzje, które mogą wpłynąć na przyszłą pracę w repozytorium:

- trwałe granice własności, bezpieczeństwa lub autoryzacji;
- kanoniczny workflow albo źródło prawdy;
- powtarzający się błąd, którego nie da się lepiej wyeliminować testem, lintem,
  kodem albo dokumentacją domenową.

Nie zapisuj pojedynczych napraw, bieżących wersji i stanów runtime, kopii
dokumentacji narzędzi ani faktów oczywistych z kodu.

## Proces

1. Zapisz propozycję z konkretnym dowodem i proponowanym miejscem docelowym.
2. Poproś użytkownika o jawne zatwierdzenie wpisu.
3. Dopiero po zatwierdzeniu zmień jego status na `accepted` i dodaj wpis tutaj.
4. Okresowo przenieś zatwierdzone wnioski do jednego miejsca: `AGENTS.md`,
   zagnieżdżonego `AGENTS.md`, skilla, dokumentacji albo mechanicznej kontroli.
5. Po destylacji zachowaj niezmienny surowy batch w `archive/`, uzupełnij indeks
   i opróżnij inbox.

Nie promuj decyzji automatycznie do zawsze ładowanych instrukcji.

## Szablon propozycji

```markdown
## YYYY-MM-DD: Krótki tytuł

- Status: proposal
- Dowód: komenda, diff, korekta użytkownika lub powtarzalny przypadek
- Zakres: gdzie i kiedy decyzja obowiązuje
- Proponowane miejsce: AGENTS.md | nested AGENTS.md | skill | docs | enforcement
- Decyzja: zwięzła reguła lub wskazanie źródła prawdy
- Niepewność: co trzeba jeszcze potwierdzić
```
