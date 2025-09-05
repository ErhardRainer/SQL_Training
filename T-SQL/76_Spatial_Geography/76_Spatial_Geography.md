# T-SQL Spatial (geometry & geography) – Übersicht  
*Arbeiten mit Geo-/Spatial-Daten, Indizes, Abfragen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `geometry` | Planarer, euklidischer Raum (Kartesisch). Nutze, wenn Daten bereits in projizierter Koordinate (z. B. UTM/Web Mercator) vorliegen. |
| `geography` | Ellipsoidisches Erdmodell (WGS84 etc.). Nutze für Lat/Lon (SRID **4326**) und geodätische Distanzen/Buffer. |
| SRID | **Spatial Reference ID**; definiert Koordinatensystem/Datum. Muss zwischen Objekten **gleich** sein (sonst Fehler/implizite Konvertierung). |
| WKT/WKB | Well-Known Text/Binary zur Repräsentation: `POINT(...)`, `LINESTRING(...)`, `POLYGON(...)`, `MULTI...`, `GEOMETRYCOLLECTION(...)`. |
| Erzeugung | `geometry::STGeomFromText(wkt, srid)` / `geography::STGeomFromText(wkt, srid)`; `Point(lat, lon, 4326)` für `geography`. |
| Topologie-Methoden | Beziehungen: `STIntersects`, `STWithin`, `STContains`, `STTouches`, `STOverlaps`, `STEquals`. |
| Metrik-Methoden | Maße: `STDistance`, `STLength`, `STArea`, `STEnvelope`, `STBuffer`, `STCentroid`, `ConvexHull`. |
| Set-Operationen | `STUnion`, `STIntersection`, `STDifference`, `STSymDifference`. |
| Gültigkeit | `STIsValid()`, `MakeValid()`, `ReorientObject()` (Geographie-Ringorientierung korrigieren). |
| Spatial Index | Spezieller Index (`CREATE SPATIAL INDEX`) für schnelle **Filterung**/NN-Queries; nutzt Grid-/Tessellation (geography/geometry). |
| BOUNDING_BOX | Für `geometry` verpflichtend (Datenausdehnung in X/Y). Für `geography` nicht nötig (globale Sphäre). |
| Filter/Präzision | Spatial Index liefert **primären Filter**; finale Präzisionsprüfung erfolgt durch die Methode (z. B. `STIntersects`). |
| KNN-Pattern | „Nearest-Neighbour“ via `ORDER BY geoCol.STDistance(@point)` + TOP/Range; oft in Kombination mit **STBuffer** (Vorausfilter). |
| SSMS Spatial Viewer | Ergebnis-Grid → Registerkarte **Spatial results** zum Visualisieren von Shapes. |
| Katalog/DMVs | `sys.spatial_indexes`, `sys.spatial_index_columns`, `sys.spatial_reference_systems`. |
| Import | Dateien (z. B. WKT/CSV/GeoJSON) einlesen → in WKT transformieren → `STGeomFromText`. (GeoJSON nativ: via JSON-Parsing + Mapping). |

---

## 2 | Struktur

### 2.1 | Grundlagen: geometry vs. geography, SRID & WKT
> **Kurzbeschreibung:** Unterschiede, typische SRIDs (4326 etc.), WKT/WKB und Grundmethoden.

- 📓 **Notebook:**  
  [`08_01_spatial_grundlagen_geometry_geography.ipynb`](08_01_spatial_grundlagen_geometry_geography.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Spatial Basics](https://www.youtube.com/results?search_query=sql+server+spatial+data+types+basics)  
  - [WKT/WKB Explained](https://www.youtube.com/results?search_query=wkt+wkb+gis)
- 📘 **Docs:**  
  - [Spatial Data (Überblick)](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server)  
  - [`geometry` & `geography` Datentypen](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/spatial-types-geometry-transact-sql)

---

### 2.2 | Objekte erstellen & validieren
> **Kurzbeschreibung:** Konstruktion aus WKT/Koordinaten, Validitätsprüfung und Korrektur.

- 📓 **Notebook:**  
  [`08_02_objekte_erstellen_validieren.ipynb`](08_02_objekte_erstellen_validieren.ipynb)
- 🎥 **YouTube:**  
  - [Create Spatial Objects](https://www.youtube.com/results?search_query=sql+server+stgeomfromtext+makevalid)
- 📘 **Docs:**  
  - [`STGeomFromText` / `MakeValid`](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/makevalid-geometry-data-type)

---

### 2.3 | Topologische Beziehungen (Intersects/Within/Contains)
> **Kurzbeschreibung:** Flächen-/Linien-/Punktbeziehungen korrekt prüfen; Unterschiede Contains vs. Within.

- 📓 **Notebook:**  
  [`08_03_topologie_intersects_within_contains.ipynb`](08_03_topologie_intersects_within_contains.ipynb)
- 🎥 **YouTube:**  
  - [STIntersects & Friends](https://www.youtube.com/results?search_query=sql+server+stintersects+stwithin+stcontains)
- 📘 **Docs:**  
  - [OGC Methods (geometry)](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/ogc-static-geometry-methods)

---

### 2.4 | Distanzen, Flächen & Buffer
> **Kurzbeschreibung:** `STDistance`, `STArea`, `STLength`, `STBuffer` – Metriken in `geometry` vs. geodätisch in `geography`.

- 📓 **Notebook:**  
  [`08_04_distance_area_buffer.ipynb`](08_04_distance_area_buffer.ipynb)
- 🎥 **YouTube:**  
  - [Distance & Buffer in SQL Server](https://www.youtube.com/results?search_query=sql+server+stdistance+stbuffer)
- 📘 **Docs:**  
  - [`STDistance` (geography)](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geography/stdistance-geography-data-type)

---

### 2.5 | Spatial Indizes – Grundlagen & Erstellung
> **Kurzbeschreibung:** Geometrie-/Geographie-Grid, BOUNDING_BOX (geometry), `CELLS_PER_OBJECT`, Performance-Charakteristik.

- 📓 **Notebook:**  
  [`08_05_spatial_index_basics_create.ipynb`](08_05_spatial_index_basics_create.ipynb)
- 🎥 **YouTube:**  
  - [Create Spatial Index](https://www.youtube.com/results?search_query=sql+server+create+spatial+index)
- 📘 **Docs:**  
  - [Create, Modify, and Drop Spatial Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/create-modify-and-drop-spatial-indexes)

---

### 2.6 | Spatial Index – Tuning & Diagnose
> **Kurzbeschreibung:** Primary Filter vs. Exact Check, Abdeckung/Selektivität prüfen, Katalog/DMVs auswerten.

- 📓 **Notebook:**  
  [`08_06_spatial_index_tuning_diagnose.ipynb`](08_06_spatial_index_tuning_diagnose.ipynb)
- 🎥 **YouTube:**  
  - [Tune Spatial Indexes](https://www.youtube.com/results?search_query=sql+server+tune+spatial+index)
- 📘 **Docs:**  
  - [Spatial Index Catalog Views](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/spatial-index-catalog-views-transact-sql)

---

### 2.7 | Nearest-Neighbour-Queries (KNN)
> **Kurzbeschreibung:** TOP-N-Nachbarn via `ORDER BY STDistance(@point)` + räumliche Vorfilter (`STBuffer`) & Index-Nutzung.

- 📓 **Notebook:**  
  [`08_07_nearest_neighbour_patterns.ipynb`](08_07_nearest_neighbour_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Nearest Neighbor with STDistance](https://www.youtube.com/results?search_query=sql+server+nearest+neighbor+stdistance)
- 📘 **Docs:**  
  - [Query Spatial Data for Nearest Neighbor](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/query-spatial-data-for-nearest-neighbor)

---

### 2.8 | Bounding, Clipping & Geometrie-Operationen
> **Kurzbeschreibung:** Envelope/Bounding Box, Ausschneiden via `STIntersection` mit Masken, Vereinfachen mit `Reduce`.

- 📓 **Notebook:**  
  [`08_08_bounding_clipping_reduce.ipynb`](08_08_bounding_clipping_reduce.ipynb)
- 🎥 **YouTube:**  
  - [Clip & Simplify Geometries](https://www.youtube.com/results?search_query=sql+server+stintersection+reduce)
- 📘 **Docs:**  
  - [`Reduce()` & `EnvelopeAngle/Center`](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/reduce-geometry-data-type)

---

### 2.9 | Import/Export: WKT/WKB, GeoJSON & Tools
> **Kurzbeschreibung:** Daten aus Dateien einlesen (BULK/OPENROWSET), JSON→WKT konvertieren, Export als WKT/GeoJSON.

- 📓 **Notebook:**  
  [`08_09_import_export_wkt_geojson.ipynb`](08_09_import_export_wkt_geojson.ipynb)
- 🎥 **YouTube:**  
  - [Load WKT/GeoJSON to SQL Server](https://www.youtube.com/results?search_query=sql+server+geojson+wkt)
- 📘 **Docs:**  
  - [Importing Spatial Data](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/importing-spatial-data)

---

### 2.10 | Performance: SARGability & Patterns
> **Kurzbeschreibung:** Vermeide Funktionsaufrufe **auf** Spalten in WHERE/JOIN; nutze vorberechnete/indizierte Spalten (z. B. Bounding Box-Koordinaten) als Vorfilter.

- 📓 **Notebook:**  
  [`08_10_performance_sargability_patterns.ipynb`](08_10_performance_sargability_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Speed Up Spatial Queries](https://www.youtube.com/results?search_query=optimize+spatial+queries+sql+server)
- 📘 **Docs:**  
  - [Best Practices for Spatial](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server#best-practices)

---

### 2.11 | Projektionen & Wahl von geometry vs. geography
> **Kurzbeschreibung:** Fehler durch ungeeignete Koordinatensysteme vermeiden; wann reprojizieren, wann `geometry` nutzen.

- 📓 **Notebook:**  
  [`08_11_projektionen_auswahl_typ.ipynb`](08_11_projektionen_auswahl_typ.ipynb)
- 🎥 **YouTube:**  
  - [Choosing Geometry or Geography](https://www.youtube.com/results?search_query=sql+server+geometry+vs+geography)
- 📘 **Docs:**  
  - [Choose between geometry and geography](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-overview#geography-and-geometry-types)

---

### 2.12 | Datenqualität: Gültigkeit, Reparatur, Orientierung
> **Kurzbeschreibung:** Selbstschnittende Polygone finden (`STIsValidDetailed`), `MakeValid`, Ringorientierung (`ReorientObject`).

- 📓 **Notebook:**  
  [`08_12_datenqualitaet_valid_repair.ipynb`](08_12_datenqualitaet_valid_repair.ipynb)
- 🎥 **YouTube:**  
  - [Fix Invalid Polygons](https://www.youtube.com/results?search_query=sql+server+makevalid+reorientobject)
- 📘 **Docs:**  
  - [`STIsValid`/`STIsValidDetailed`](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/stisvaliddetailed-geometry-data-type)

---

### 2.13 | Mehrteilige Geometrien & Collections
> **Kurzbeschreibung:** `MULTI*`-Objekte, `GEOMETRYCOLLECTION`, Explode/Union/Merge-Patterns.

- 📓 **Notebook:**  
  [`08_13_multi_geometry_collections.ipynb`](08_13_multi_geometry_collections.ipynb)
- 🎥 **YouTube:**  
  - [Work with MultiPolygons/Collections](https://www.youtube.com/results?search_query=sql+server+multipolygon+geometrycollection)
- 📘 **Docs:**  
  - [Geometry Collections](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/collections-geometry-data-type)

---

### 2.14 | Räumliche Joins & Aggregate
> **Kurzbeschreibung:** Punkt-in-Polygon-Zuordnung, Linien-Overlay, Area/Length-Aggregate; Performance mit Vorfiltern.

- 📓 **Notebook:**  
  [`08_14_spatial_joins_aggregate.ipynb`](08_14_spatial_joins_aggregate.ipynb)
- 🎥 **YouTube:**  
  - [Spatial Joins in SQL Server](https://www.youtube.com/results?search_query=sql+server+spatial+join)
- 📘 **Docs:**  
  - [Query Spatial Data for Relationships](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/query-spatial-data-for-relationships)

---

### 2.15 | Visualisierung & Werkzeuge (SSMS, extern)
> **Kurzbeschreibung:** SSMS Spatial Results, Export zu GIS-Tools (QGIS), einfache SVG/GeoJSON-Exports.

- 📓 **Notebook:**  
  [`08_15_visualisierung_tools.ipynb`](08_15_visualisierung_tools.ipynb)
- 🎥 **YouTube:**  
  - [Visualize Spatial Results in SSMS](https://www.youtube.com/results?search_query=ssms+spatial+results)
- 📘 **Docs:**  
  - [Spatial Results in SSMS (Hinweise)](https://learn.microsoft.com/en-us/sql/ssms/f1-help/spatial-results-tab)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Falscher Typ (geography/geometry), fehlende SRIDs, kein Spatial-Index, `STDistance` ohne Vorfilter, invalides WKT, ungeeignete BOUNDING_BOX, Extensive Funktionen in WHERE, kein Exact-Check nach Index-Filter.

- 📓 **Notebook:**  
  [`08_16_spatial_antipatterns_checkliste.ipynb`](08_16_spatial_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Spatial Mistakes](https://www.youtube.com/results?search_query=sql+server+spatial+mistakes)
- 📘 **Docs/Blog:**  
  - [Spatial Best Practices & Pitfalls](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Spatial Data – Einstieg & Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server)  
- 📘 Microsoft Learn: [`geography` Datentyp – Methoden](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geography/geography-data-type-methods)  
- 📘 Microsoft Learn: [`geometry` Datentyp – Methoden](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/geometry-data-type-methods)  
- 📘 Microsoft Learn: [Create/Modify/Drop Spatial Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/create-modify-and-drop-spatial-indexes)  
- 📘 Microsoft Learn: [Query Spatial Data for Nearest Neighbor](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/query-spatial-data-for-nearest-neighbor)  
- 📘 Microsoft Learn: [Importing Spatial Data (WKT/WKB/Shape)](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/importing-spatial-data)  
- 📘 Microsoft Learn: [Spatial Index Catalog Views (`sys.spatial_*`)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/spatial-index-catalog-views-transact-sql)  
- 📘 Microsoft Learn: [`sys.spatial_reference_systems`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-spatial-reference-systems-transact-sql)  
- 📘 Microsoft Learn: [`MakeValid`, `ReorientObject`, Validität](https://learn.microsoft.com/en-us/sql/t-sql/spatial-geometry/makevalid-geometry-data-type)  
- 📝 SQLPerformance: *Tuning Spatial Indexes & Queries* – https://www.sqlperformance.com/?s=spatial  
- 📝 Simple Talk (Redgate): *Working with SQL Server Spatial Data* – https://www.red-gate.com/simple-talk/  
- 📝 Erik Darling / Brent Ozar: *Nearest-Neighbor & spatial Index Gotchas* – Blogsuche  
- 📝 GIS StackExchange: *SQL Server Spatial Patterns* – Threads/Best Practices  
- 🎥 YouTube (Data Exposed): *Spatial Data in SQL Server – Deep Dive* – Suchlink  
- 🎥 YouTube: *Spatial Index & KNN Demo* – Suchlink  
