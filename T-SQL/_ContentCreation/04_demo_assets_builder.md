# 04 - Demo Assets Builder

## Aufgabe
Leite aus dem validierten Blueprint die konkrete Lab-, Setup- und Cleanup-Strategie ab.
Nutze dafuer `Templates/demo_assets.template.yaml`.

## Ziel
Bevor Markdown- und SQL-Zellen geschrieben werden, muss feststehen:
- welche Objekte gebraucht werden
- wie sie sicher aufgebaut werden
- welche manuellen Voraussetzungen gelten
- wie mehrere Sessions oder Betriebszustande nachgestellt werden

## Pflichtfelder
- `demo_assets.notebook_file`
- `demo_assets.lab_profile`
- `demo_assets.setup_cells`
- `demo_assets.baseline_queries`
- `demo_assets.manual_steps`
- `demo_assets.multi_session_blocks`
- `demo_assets.cleanup_cells`
- `demo_assets.safeguards`

## Typische Setup-Muster
- Dedizierte Demo-Datenbank wie `BITest` oder ein themenspezifischer Lab-Name
- Demo-Tabellen mit kleiner, aber bewusst gewaehlter Datenmenge
- Idempotentes `DROP IF EXISTS` nur fuer Demo-Objekte
- Sichtungsquery direkt nach dem Setup
- Optionaler Rueckbau am Ende

## Typische Admin-/Feature-Muster
- klare Voraussetzungen statt automatischer Feature-Aktivierung
- manuelle Vorarbeiten explizit nummerieren
- Beobachtungsqueries fuer DMVs, Kataloge oder History-Tabellen
- Session A/B- oder Publisher/Distributor-Hinweise als getrennte Bloeke

## Sicherheitsregeln
- Niemals echte Produktionsobjekte im Setup referenzieren.
- Destruktive Beispiele nur auf klar benannte Demo-Objekte anwenden.
- Wenn ein gefaehrlicher Schritt didaktisch wichtig ist, kommentiere ihn sichtbar oder markiere ihn als manuell.
- Bei Backup, Restore, Agent, HA/DR, CDC, CT, Replikation und Security muss mindestens ein Sicherheits- oder Berechtigungshinweis enthalten sein.

## Ergebnis
Das Demo-Asset-YAML ist die direkte Grundlage fuer:
- die Setup-Markdown-Zellen
- die Setup-Codezellen
- Baseline-/Sichtungszellen
- ggf. Session-A/B-Sequenzen
- Cleanup oder Reset
