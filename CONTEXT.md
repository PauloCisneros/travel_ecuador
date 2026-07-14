# Travel Ecuador — Contexto de la App

## 1. Descripción General

Aplicación móvil Flutter para descubrir y compartir destinos turísticos en Ecuador. Los usuarios pueden registrarse, explorar destinos, guardar favoritos, calificar con estrellas, dejar comentarios, y agregar nuevos lugares con geolocalización y datos climáticos.

---

## 2. Stack Tecnológico

| Componente | Tecnología |
|---|---|
| UI | Flutter 3.44 (Material 3) |
| Estado | Provider + ChangeNotifier |
| Backend | Supabase (Auth, Postgres, Storage) |
| APIs externas | OpenWeatherMap (clima), Photon/OSM (geocodificación) |
| Almacenamiento local | SharedPreferences (favoritos) |
| Mapas/Navegación | url_launcher (Google Maps, Waze) |
| GPS | geolocator |

---

## 3. Arquitectura

### Patrón: Service-Provider-Screen

```
Pantallas (UI)
    |  watch / read
    v
Providers (ChangeNotifier)
    |  instancian y llaman
    v
Servicios (lógica de negocio, APIs, DB)
    |  consultan
    v
Backend/APIs (Supabase, OpenWeatherMap, Photon)
```

**Principios:**
- Los **Providers** gestionan el estado y notifican cambios a las pantallas via `notifyListeners()`.
- Los **Servicios** son clases Dart simples (sin estado compartido entre pantallas) que encapsulan llamadas a Supabase, APIs REST, o almacenamiento local.
- Las **Pantallas** son widgets que se suscriben a los providers con `context.watch<>()` o `context.read<>()`.

### Inyección de Dependencias

No se usa un framework de DI (GetIt, Riverpod, etc.). Los providers se registran globalmente en `MultiProvider` en `main.dart`. Los servicios se instancian directamente donde se necesitan (dentro de providers o pantallas), sin inyección formal:

```dart
// Dentro de un Provider:
final FavoritoService _favoritoService = FavoritoService();

// Dentro de una pantalla:
final visitaService = VisitaService();
```

---

## 4. Gestión de Estado — Providers

### SessionProvider
- **Estado:** `AppUser? _user`, `bool _isLoading`
- **Expone:** `user`, `isLoading`, `isLoggedIn`
- **Métodos:** `register()`, `login()`, `logout()`, `updateProfile()`, `updateAvatar()`
- **Backend:** Supabase Auth + tabla `users` (incluye `avatar_url`)
- **Nota:** El constructor llama a `_init()` que restaura sesión existente de Supabase.

### FavoritoProvider
- **Estado:** `List<String> _favoritosIds`, `List<Destino> _destinosFavoritos`, `bool _isLoading`
- **Expone:** `favoritosIds`, `destinosFavoritos`, `isLoading`, `isFavorito(id)`
- **Métodos:** `loadFavoritos()`, `loadDestinosFavoritos()`, `addFavorito()`, `removeFavorito()`, `toggleFavorito()`, `clearFavoritos()`, `notify()`
- **Backend:** SharedPreferences (local, NO Supabase)

### VisitaProvider
- **Estado:** `List<Visita> _visitas`, `double _promedioCalificacion`, `int _totalVisitas`, `bool _userHasVisited`, `Visita? _userVisita`
- **Expone:** `visitas`, `promedioCalificacion`, `totalVisitas`, `isLoading`, `userHasVisited`, `userVisita`
- **Métodos:** `loadVisitas()`, `checkUserVisited()`, `addVisita()`, `updateVisita()`, `deleteVisita()`, `clear()`
- **Backend:** Supabase tabla `visitas`

### DestinoProvider
- **Estado:** `List<Destino> _destinos`, `bool _isLoading`
- **Expone:** `destinos`, `isLoading`, `error`
- **Métodos:** `loadDestinos()`, `addDestino()`, `deleteDestino()`, `clearDestinos()`
- **Backend:** Supabase tabla `destinos`

---

## 5. Servicios

| Servicio | Backend / API | Propósito |
|---|---|---|
| `AuthService` | Supabase Auth + `users` | Registro, login, logout, perfil (incluye `avatar_url`) |
| `FavoritoService` | SharedPreferences | Persistencia local de favoritos |
| `VisitaService` | Supabase `visitas` | CRUD de visitas/calificaciones con joins + resumen de calificaciones |
| `StorageService` | Supabase Storage (`destinos`, `avatars`) | Subida/borrado de imágenes + avatar con upsert |
| `WeatherService` | OpenWeatherMap API | Clima por coordenadas |
| `GeocodingService` | Photon API (OSM) | Nombre de lugar → lat/lng |
| `GpsService` | geolocator (GPS) | Ubicación actual del dispositivo |
| `SnackbarService` | Flutter UI | Snackbars con mensajes amigables (incluye detección de errores de avatar) |

---

## 6. Backend — Supabase

- **URL:** `https://shjbxvpgxkmmkphsjkar.supabase.co`
- **Auth:** Email + password, sesión persistente
- **Tablas:**

| Tabla | Propósito |
|---|---|
| `users` | Perfiles (`uid`, `nombre`, `email`, `avatar_url`) |
| `destinos` | Lugares turísticos con coordenadas, clima, imagen |
| `visitas` | Calificaciones y comentarios por usuario/destino |

- **Storage buckets:**
  - `destinos` — imágenes de destinos (límite 1 MB)
  - `avatars` — fotos de perfil (límite 2 MB, upsert por uid, público)

---

## 7. APIs Externas

### OpenWeatherMap
- **Endpoint:** `api.openweathermap.org/data/2.5/weather`
- **API Key:** `ba1f3e450b5da7f1096c86a535403b42`
- **Uso:** Obtener clima, temperatura y humedad por coordenadas (métricas, español).

### Photon (Komoot / OpenStreetMap)
- **Endpoint:** `photon.komoot.io/api/`
- **Uso:** Geocodificación de nombres de lugares a coordenadas.
- **Detalles:** No soporta `lang=es` (retorna 400). Se concatenan `,Ecuador` al query y se filtran resultados por `countrycode: EC`. Retorna `[lon, lat]` (GeoJSON).

---

## 8. Navegación / Rutas

```
SplashScreen (3s animación)
  └── AuthGate (decide según SessionProvider.isLoggedIn)
       ├── LoginScreen (si no logueado)
       └── MainTabsScreen (BottomNavigationBar)
            ├── [0] HomeScreen → DestinoDetailScreen / AddDestinoScreen
            ├── [1] FavoritesScreen → DestinoDetailScreen
            └── [2] ProfileScreen → AddDestinoScreen (editar) / DestinoDetailScreen
```

---

## 9. Estructura del Proyecto

```
lib/
├── main.dart                     # Inicialización, providers, tema, navegación
├── splash_screen.dart            # Pantalla de carga animada (3s)
├── theme/
│   └── app_theme.dart            # Paleta AppColors + temas globales (Material 3)
├── models/
│   ├── destino_model.dart        # Destino (id, nombre, provincia, coord, clima, etc.)
│   ├── user.dart                 # AppUser (uid, nombre, email, avatarUrl)
│   ├── favorito_model.dart       # Favorito (no usado activamente — migración futura)
│   ├── visita_model.dart         # Visita (calificación 1-5, comentario)
│   ├── categorias_destino.dart   # Mapas de categorías con labels e iconos
│   └── provincias_ec.dart        # Lista constante de 24 provincias
├── providers/
│   ├── session_provider.dart     # Estado de autenticación + updateAvatar
│   ├── destino_provider.dart     # CRUD de destinos
│   ├── favorito_provider.dart    # Favoritos (local SharedPreferences)
│   └── visita_provider.dart      # Visitas/calificaciones por destino
├── screens/
│   ├── login_screen.dart         # Login/registro con validación
│   ├── home_screen.dart          # Lista de destinos + búsqueda insensible a acentos + FAB
│   ├── favorites_screen.dart     # Favoritos + búsqueda + filtros categoría
│   ├── profile_screen.dart       # Perfil con avatar editable, dashboard, edit nombre, logout
│   ├── destino_detail_screen.dart# Detalle + reseñas minimalistas + AppBar editar/eliminar (dueño)
│   └── add_destino_screen.dart   # Formulario con DropdownMenu buscable + auto-geocoding
├── services/
│   ├── auth_service.dart         # Supabase Auth + users table (incluye avatar_url)
│   ├── favorito_service.dart     # SharedPreferences persistencia
│   ├── visita_service.dart       # Supabase visitas CRUD + agregaciones + resumen
│   ├── storage_service.dart      # Supabase Storage (destinos + avatars bucket)
│   ├── weather_service.dart      # OpenWeatherMap API
│   ├── geocoding_service.dart    # Photon API (OSM)
│   ├── gps_service.dart          # geolocator GPS
│   └── snackbar_service.dart     # Snackbars con mensajes amigables
└── widgets/
    ├── destino_card.dart         # Card resumen (corazón, clima, estrellas)
    ├── destino_card_editable.dart# Card con editar/eliminar (overlays oscuros)
    └── clima_resumen.dart        # Widget de clima reusable
```

---

## 10. Flujo de Datos Clave

### Crear un Destino
1. Usuario llena formulario en `AddDestinoScreen` (nombre, provincia, categoría, descripción)
2. Al llenar nombre y provincia, **auto-geocoding con debounce 800ms** → `GeocodingService.geocode()` → `WeatherService.getWeather()` (sin botón manual)
3. Selecciona imagen → `StorageService.uploadImage()` → URL pública
4. Guarda → inserta en Supabase `destinos` via cliente directo
5. Retorna `true` a la pantalla anterior → recarga

### Calificar un Destino
1. Usuario va a `DestinoDetailScreen`
2. Toca icono `reviews_rounded` en AppBar (si no ha calificado)
3. Selecciona estrellas (AppColors.sol), opcionalmente escribe comentario
4. `VisitaProvider.addVisita()` → `VisitaService.createVisita()` → inserta en Supabase `visitas`
5. Provider recalcula promedio y actualiza UI

### Favoritos
1. Usuario toca corazón en `DestinoCard`
2. `FavoritoProvider.toggleFavorito()` → `FavoritoService.addFavorito/removeFavorito()` → `SharedPreferences`
3. Provider actualiza listas internas y notifica
4. UI se re-renderiza (corazón lleno/vacío)

### Avatar (foto de perfil)
1. Usuario toca avatar en `ProfileScreen`
2. Bottom sheet: cámara o galería → `ImagePicker.pickImage()`
3. `StorageService.uploadAvatar()` → bucket `avatars` (upsert por uid, 2 MB límite)
4. `SessionProvider.updateAvatar()` → actualiza `avatar_url` en tabla `users`
5. Recarga perfil y muestra nueva foto

---

## 11. Decisiones de Diseño

- **Favoritos en local (SharedPreferences):** No hay tabla `favoritos` en Supabase. Los favoritos son por-dispositivo, no sincronizados entre sesiones. Cada favorito almacena el objeto `Destino` completo serializado como JSON.
- **Calificaciones no denormalizadas:** El promedio se calcula en tiempo real desde `visitas` al cargar la pantalla. No se cachea en la tabla `destinos`.
- **Geocoding con Photon (OSM):** Gratuito, sin API key, basado en OpenStreetMap. Encuentra ciudades, parques nacionales, y puntos de interés en Ecuador.
- **Auto-geocoding con debounce:** Al crear/editar un destino, geocoding + clima se disparan automáticamente 800ms después de que el usuario llena nombre y provincia. Sin botón manual.
- **DropdownMenu con búsqueda:** Provincia y categoría usan `DropdownMenu` con `enableSearch: true` + `enableFilter: true` — el usuario escribe para filtrar entre 24 opciones.
- **Avatar en bucket separado (`avatars`):** Bucket público con upsert por uid, manejo de errores separado (upload vs db) con mensajes específicos.
- **Búsqueda insensible a acentos:** Tanto en Home como en Favoritos, la búsqueda normaliza á→a, é→e, etc., para encontrar "Cafe" al buscar "Café".
- **AppColors como paleta fija:** Sin colores generados por `fromSeed` que introducían tintes morados en dropdowns. Se forza `canvasColor`, `surfaceContainerHigh`, y `menuTheme` a blancos para coherencia visual.
- **Diálogos consistentes:** Todos los botones de acción destructiva usan `AppColors.musgo` (gris) en vez de rojo. Cancelar hereda `AppColors.sol` del `TextButtonTheme`.
- **Botones de reseña:** Cancelar como `OutlinedButton`, Publicar como `FilledButton` — ambos con el mismo tamaño (flex:1).
- **SnackbarService centralizado:** Traduce excepciones técnicas (`AuthException`, `PostgrestException`, `SocketException`, etc.) a mensajes amigables en español, sin exponer detalles internos. Incluye detección específica para errores de avatar (bucket/columna faltante).
- **Provider + ChangeNotifier:** Elección pragmática para app pequeña/mediana. No se requiere Bloc, Riverpod, o Redux.
- **Botones de acción en cards:** Editar/eliminar en `DestinoCardEditable` usan overlays semitransparentes oscuros (consistente con badge de categoría) en vez de círculos blancos.
- **AppBar de dueño:** En `DestinoDetailScreen`, si el usuario es dueño del destino, aparecen iconos de editar y eliminar en la AppBar.

---

## 12. Seguridad

- **Supabase publishable key** expuesta en cliente (es el diseño de Supabase — RLS policies protegen los datos).
- **No se exponen mensajes de error internos** — `SnackbarService` traduce a mensajes genéricos.
- **Autenticación:** Solo email/password. No hay 2FA ni magic links.
- **Storage:** Imágenes subidas al bucket `destinos` con políticas RLS (asumidas). Bucket `avatars` público con upsert.
- **Aleatoriedad:** Al registrarse se genera un nombre aleatorio de 8 dígitos si no se proporciona uno.
- **Eliminación segura:** Solo el dueño (`uid`) puede eliminar sus destinos (filtro `.eq('uid', session.user!.uid)`).

---

## 13. Próximas Mejoras Potenciales

- Implementar Overpass API (OpenStreetMap) para "sitios turísticos cercanos".
- Soporte offline (Hive/Isar para datos locales).
- Mejorar dashboard de perfil con más estadísticas y gráficos.
