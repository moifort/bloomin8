# Plan : Localisation FR/EN de l'app iOS Canvas

## Contexte
L'app iOS a toutes ses chaînes en français, codées en dur dans le code Swift. On veut ajouter le support FR + EN via le système de localisation natif iOS (String Catalogs `.xcstrings`).

## Approche : String Catalogs (`.xcstrings`)

Format JSON moderne d'Apple (Xcode 15+). Un seul fichier par target contient toutes les traductions. Le projet est déjà configuré avec `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`.

### Stratégie pour les chaînes

**SwiftUI (`Text`, `Label`, `Button`, `.alert`)** : ces vues acceptent déjà des `LocalizedStringKey` automatiquement — les chaînes littérales sont localisées sans changement de code. Il suffit d'ajouter les traductions dans le String Catalog.

**Code non-SwiftUI (erreurs, statusText dans ViewModel)** : remplacer les `String` littérales par `String(localized:)` pour qu'elles participent à la localisation.

### Fichiers à créer

1. **`ios/Canvas/Canvas/Localizable.xcstrings`** — String Catalog pour l'app principale (FR + EN)
2. **`ios/Canvas/CanvasBatteryWidget/Localizable.xcstrings`** — String Catalog pour le widget (FR + EN)

### Fichiers à modifier

3. **`ios/Canvas/Canvas/AppViewModel.swift`** — Remplacer les chaînes de `statusText` et `errorText` par `String(localized:)`
4. **`ios/Canvas/Canvas/PhotoModels.swift`** — Remplacer les `errorDescription` de `AppError` par `String(localized:)`
5. **`ios/Canvas/Canvas/UploadService.swift`** — Remplacer les `errorDescription` des enums d'erreur par `String(localized:)`
6. **`ios/Canvas/Canvas/PhotoLibraryService.swift`** — Remplacer les `errorDescription` de `FetchImageError` par `String(localized:)`
7. **`ios/Canvas/Canvas/ContentView.swift`** — Remplacer la chaîne computée `"Indisponible"` et le pluriel `jour/jours` par des chaînes localisées

### Inventaire des chaînes

**ContentView.swift (auto-localisées via SwiftUI Text/Label/Button)** :
- "Actualiser", "OK", "Erreur"
- "Serveur", "BLOOMIN8", "Intervalle"
- "Batterie", "Dernière charge complète"
- "Aucun album", "Aucun album contenant des photos n'a été trouvé."
- "Album", "Upload en cours", "Annuler"
- "Accès Photos requis", "L'application a besoin d'accéder à vos photos pour uploader un album.", "Autoriser l'accès"
- "Uploader l'album", "Démarrage...", "Démarrer la playlist"
- Footer text
- "⚠️ Batterie faible, pensez à recharger le Canvas"

**ContentView.swift (nécessite `String(localized:)`)** :
- `"Indisponible"` (dans `canvasBatteryPercentageText`)
- `"\(days) jour\(days > 1 ? "s" : "")"`  — remplacer par une chaîne avec substitution

**AppViewModel.swift (nécessite `String(localized:)`)** :
- "Lecture de l'album...", "Suppression des photos serveur...", "Upload en cours...", "Upload annule."
- "Lancement de la playlist..."
- "Termine: \(progress.uploaded) envoyees, \(progress.failed) echecs."
- "Upload \(progress.processed)/\(progress.total)"
- "Acces Photos refuse.", "URL Canvas invalide.", "Intervalle cron invalide (entier > 0 requis)."

**PhotoModels.swift** : 4 chaînes d'erreur AppError
**UploadService.swift** : ~12 chaînes d'erreur (UploadError, PlaylistError, ImageError, CanvasStatusError) + "Playlist lancee.", "Photos supprimees."
**PhotoLibraryService.swift** : 3 chaînes d'erreur + "Album sans nom"

**Widget** : "Canvas Battery", "Displays the latest Canvas battery level.", "--", "\(days)j"

## Étapes d'implémentation

1. Modifier les fichiers Swift pour utiliser `String(localized:)` sur les chaînes non-SwiftUI
2. Créer `Localizable.xcstrings` pour l'app avec toutes les traductions FR + EN
3. Créer `Localizable.xcstrings` pour le widget avec ses traductions FR + EN
4. Mettre à jour le `project.pbxproj` pour référencer les fichiers `.xcstrings` et déclarer les langues FR + EN

## Vérification

- Build le projet dans Xcode pour vérifier que les fichiers sont bien reconnus
- Changer la langue du simulateur en anglais et vérifier que les chaînes s'affichent en EN
- Changer en français et vérifier le FR
