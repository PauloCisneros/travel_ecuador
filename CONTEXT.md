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
| APIs externas | OpenWeatherMap (clima), Photon/OSM (geocodificación), Overpass API (OSM) |
| Almacenamiento local | SharedPreferences (legacy `favorito_service.dart` — no usado por providers) |
| Mapas/Navegación | flutter_map (OSM), url_launcher (Google Maps, Waze) |
| GPS | geolocator |
| Chatbot | Botpress v3.6 webview embebido (EcuGuía) con JavaScript Bridge |

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
final FavoritoSupabaseService _favoritoService = FavoritoSupabaseService();

// Dentro de una pantalla:
final visitaService = VisitaService();
```

**Providers registrados en `MultiProvider` (4):** `SessionProvider`, `FavoritoProvider`, `VisitaProvider`, `DestinoUpdateNotifier`.

**Nota:** `DestinoProvider` existe en `lib/providers/destino_provider.dart` pero **no está registrado** en `MultiProvider` ni es usado por ninguna pantalla. Es código muerto. `HomeScreen` consulta Supabase directamente sin pasar por `DestinoProvider`.

### Ubicación de AuthGate y MainTabsScreen

`AuthGate`, `MainTabsScreen`, y `SplashScreenWrapper` están definidos en `main.dart` (no en archivos separados). `AuthGate` decide entre `LoginScreen` y `MainTabsScreen` según `SessionProvider.isLoggedIn`. `MainTabsScreen` usa `IndexedStack` para preservar estado entre 3 tabs.

---

## 4. Gestión de Estado — Providers

### SessionProvider
- **Estado:** `AppUser? _user`, `bool _isLoading`
- **Expone:** `user`, `isLoading`, `isLoggedIn`
- **Métodos:** `register()`, `login()`, `logout()`, `updateProfile(nombre, {email, avatarUrl})`, `updateAvatar()`
- **Backend:** Supabase Auth + tabla `users` (incluye `avatar_url`)
- **Nota:** El constructor llama a `_init()` que ejecuta `syncUserProfile()` (crea perfil si no existe en tabla `users`) y luego `_loadUserProfile()`.

### DestinoProvider
- **Estado:** `List<Destino> _destinos`, `bool _isLoading`, `String? _error`
- **Expone:** `destinos`, `isLoading`, `error`
- **Métodos:** `loadDestinos(uid)`, `addDestino(destino)`, `deleteDestino(id, uid)`, `clearDestinos()`
- **Backend:** Supabase tabla `destinos` (ordenado por `created_at DESC`)
- **Nota:** `deleteDestino` filtra por `uid` del dueño. No es usado por las pantallas principales (HomeScreen carga destinos directamente con queries propias).

### FavoritoProvider
- **Estado:** `List<String> _favoritosIds`, `List<Destino> _destinosFavoritos`, `bool _isLoading`, `String? _error`, `int _ultimaModificacionDestinos`
- **Expone:** `favoritosIds`, `destinosFavoritos`, `isLoading`, `error`, `isFavorito(id)`, `ultimaModificacionDestinos`
- **Métodos:** `loadFavoritos()`, `loadDestinosFavoritos()`, `addFavorito()`, `removeFavorito()`, `toggleFavorito()`, `clearFavoritos()`, `notify()`, `refreshDestinosFavoritos()`
- **Backend:** Supabase tabla `favoritos`
- **Nota:** `loadDestinosFavoritos()` y `refreshDestinosFavoritos()` hacen join con `users` para obtener `nombre_creador`. `_ultimaModificacionDestinos` es un timestamp que se incrementa al llamar `refreshDestinosFavoritos()` **y también en `addFavorito()` y `removeFavorito()`**. HomeScreen y FavoritesScreen lo observan para recargar automáticamente cuando se edita un destino desde DestinoDetailScreen **o se agrega/quita favorito**.

### VisitaProvider
- **Estado:** `List<Visita> _visitas`, `double _promedioCalificacion`, `int _totalVisitas`, `bool _isLoading`, `String? _error`, `bool _userHasVisited`, `Visita? _userVisita`
- **Expone:** `visitas`, `promedioCalificacion`, `totalVisitas`, `isLoading`, `error`, `userHasVisited`, `userVisita`
- **Métodos:** `loadVisitas()`, `checkUserVisited()`, `addVisita(nombreUsuario)`, `updateVisita()`, `deleteVisita()`, `clear()`
- **Backend:** Supabase tabla `visitas`

### DestinoUpdateNotifier
- **Estado:** `int _version`
- **Expone:** `version`
- **Métodos:** `notify()` (incrementa `_version` y llama `notifyListeners()`)
- **Propósito:** Notificador ligero de cambios entre pantallas. Cuando se edita un destino desde `DestinoDetailScreen`, se llama a `notify()`. `HomeScreen` y `FavoritesScreen` observan `version` para recargar datos automáticamente.
- **Backend:** Ninguno (solo estado en memoria)

---

## 5. Servicios

| Servicio | Backend / API | Propósito |
|---|---|---|
| `AuthService` | Supabase Auth + `users` | Registro, login, logout, perfil, `syncUserProfile()` (crea perfil si falta) |
| `FavoritoSupabaseService` | Supabase `favoritos` | CRUD de favoritos en base de datos |
| `FavoritoService` (legacy) | SharedPreferences | CRUD local de favoritos (ya no usado por ningún provider) |
| `VisitaService` | Supabase `visitas` | CRUD visitas, joins con `users`, `_actualizarCache()` (actualiza `promedio_calificacion` y `total_calificaciones` en `destinos`), `getResumenCalificacionesForDestinos()` (para dashboard perfil) |
| `StorageService` | Supabase Storage (`destinos`, `avatars`) | Subida/borrado imágenes + avatar con upsert (soporte web y móvil) |
| `WeatherService` | OpenWeatherMap API | Clima por coordenadas (métricas, español, timeout 15s) |
| `GeocodingService` | Photon API (OSM) | Nombre de lugar → lat/lng con fallback sin provincia, timeout 30s, filtrado por countrycode EC |
| `GpsService` | geolocator (GPS) | Ubicación actual del dispositivo, fallback a última conocida, timeout 15s |
| `OverpassService` | Overpass API | Búsqueda sitios turísticos cercanos (tourism, radio 5km, POST con fallback GET, timeout 25s, top 10) |
| `SnackbarService` | Flutter UI | Snackbars con mensajes amigables (`mostrarExito`, `mostrarAdvertencia`, `mostrarError`), traduce excepciones técnicas (Auth, Postgrest, Storage, Socket, Format, ubicación, clima, mapas, avatar upload/db, timeout, geocoding, cámara/galería) |

---

## 6. Backend — Supabase

- **URL:** `https://zjjalezwyjrlykkhtwcj.supabase.co`
- **Auth:** Email + password, sesión persistente
- **Tablas:**

| Tabla | Propósito |
|---|---|
| `users` | Perfiles (`uid`, `nombre`, `email`, `avatar_url`) |
| `destinos` | Lugares turísticos con coordenadas, clima, imagen, `promedio_calificacion`, `total_calificaciones` (actualizados por VisitaService) |
| `visitas` | Calificaciones y comentarios por usuario/destino |
| `favoritos` | Favoritos por usuario (`uid`, `destino_id`) |

- **Storage buckets:**
  - `destinos` — imágenes de destinos (límite 1 MB)
  - `avatars` — fotos de perfil (límite 2 MB, upsert por uid, público)

---

## 7. APIs Externas

### OpenWeatherMap
- **Endpoint:** `api.openweathermap.org/data/2.5/weather`
- **API Key:** `ba1f3e450b5da7f1096c86a535403b42`
- **Uso:** Obtener clima, temperatura y humedad por coordenadas (métricas, español). Timeout 15s.

### Photon (Komoot / OpenStreetMap)
- **Endpoint:** `photon.komoot.io/api/`
- **Uso:** Geocodificación de nombres de lugares a coordenadas.
- **Detalles:** No soporta `lang=es` (retorna 400). Se concatenan `,Ecuador` al query y se filtran resultados por `countrycode: EC`. Retorna `[lon, lat]` (GeoJSON). Timeout 30s. Fallback: si `"$nombre,$provincia,Ecuador"` falla, reintenta con `"$nombre,Ecuador"`.

### Overpass API (OpenStreetMap)
- **Endpoint:** `overpass-api.de/api/interpreter`
- **Uso:** Búsqueda de lugares turísticos cercanos a una ubicación GPS.
- **Detalles:** Consulta `node` y `way` con `tourism=attraction|museum|viewpoint|gallery` en radio de 5km. Usa `out body center` para obtener centroides de ways. POST con fallback GET, timeout 25s. Sin API key. Retorna top 10 ordenados por distancia.

---

## 8. Navegación / Rutas

```
SplashScreen (animación 2.6s: ícono escala+resplandor, título slide, puntos pulsantes)
  └── AuthGate (decide según SessionProvider.isLoggedIn)
       ├── LoginScreen (si no logueado)
       └── MainTabsScreen (IndexedStack — preserva estado entre tabs)
            ├── [0] HomeScreen → DestinoDetailScreen / AddDestinoScreen / ChatbotScreen (push)
            ├── [1] FavoritesScreen → DestinoDetailScreen
            └── [2] ProfileScreen → AddDestinoScreen (editar) / DestinoDetailScreen
```

**Nota:** El botón de cerrar sesión se encuentra en el header de ProfileScreen (esquina superior derecha junto al avatar), no flotando sobre el contenido. ChatbotScreen se abre como PageRouteBuilder con FadeTransition desde HomeScreen, no como tab separado.

---

## 9. Estructura del Proyecto

```
lib/
├── main.dart                     # Inicialización, MultiProvider, MainApp, SplashScreenWrapper, AuthGate, MainTabsScreen (IndexedStack + BottomNav 3 tabs)
├── splash_screen.dart            # Pantalla de carga animada (2.6s con secuencia icono→resplandor→título→puntos)
├── theme/
│   └── app_theme.dart            # Paleta AppColors (11 colores) + temas globales Material 3 (text, inputs, buttons, cards, FAB, chips, badges, snackbar, bottomNav, diálogos)
├── utils/
│   └── distancia.dart            # Función Haversine para calcular km entre coordenadas
├── models/
│   ├── destino_model.dart        # Destino (id, nombre, provincia, coord, clima, categoría, uid, nombreCreador, promedioCalificacion, totalCalificaciones, copyWith, factory create)
│   ├── user.dart                 # AppUser (uid, nombre, email, avatarUrl)
│   ├── favorito_model.dart       # Favorito (no usado activamente)
│   ├── visita_model.dart         # Visita (calificación 1-5, comentario, nombreUsuario)
│   ├── sitio_osm.dart            # SitioOsm para resultados de Overpass API
│   ├── categorias_destino.dart   # 24 categorías con keys y labels
│   └── provincias_ec.dart        # Lista constante de 24 provincias
├── providers/
│   ├── session_provider.dart     # Estado de autenticación + updateProfile/updateAvatar + syncUserProfile
│   ├── destino_provider.dart     # CRUD de destinos en Supabase (NO registrado en MultiProvider — código muerto)
│   ├── favorito_provider.dart    # Favoritos (Supabase) con joins a users + refreshDestinosFavoritos + notify
│   ├── visita_provider.dart      # Visitas/calificaciones por destino (add, update, delete, checkUserVisited)
│   └── destino_update_notifier.dart # Notificador ligero para recarga post-edit (versión counter)
├── screens/
│   ├── login_screen.dart         # Login/registro con icono app, toggle contraseña, validación
│   ├── home_screen.dart          # Paginación 20 items, scroll infinito, búsqueda, categorías chips, filtros bottom sheet (categoría/provincia/rating), "Cerca de mí" + Overpass, chatbot, logout, observer ultimaModificacionDestinos y DestinoUpdateNotifier
│   ├── favorites_screen.dart     # Favoritos + búsqueda insensible acentos + filtros categoría chips + estados empty/sin resultados + observer ultimaModificacionDestinos y DestinoUpdateNotifier
│   ├── profile_screen.dart       # Avatar cámara/galería + botón logout en header, edit nombre, dashboard (bar chart: desglose 5★-1★ con barras de colores, stats, mejor valorado, Explorador badge), mis destinos (DestinoCardEditable con edit/delete overlays), scroll fluido, refresh automático al cambiar favoritos/editar/eliminar
│   ├── chatbot_screen.dart       # Webview Botpress v3.6 embebido con JavaScript Bridge + MutationObserver
│   ├── destino_detail_screen.dart# Mapa OSM interactivo, "Cómo llegar" (Google Maps/Waze/Copiar coord), reseñas con fechas relativas, edit/delete por dueño, fav inline, PopScope, recarga destino post-edit
│   └── add_destino_screen.dart   # Modo edición, params pre-llenados desde OSM, Autocomplete provincia/categoría, auto-geocoding debounce 800ms, clima en tarjeta, image picker (web+móvil), campos manuales lat/lng
├── services/
│   ├── auth_service.dart         # Supabase Auth + users table (signUp, signIn, signOut, syncUserProfile, updateUserProfile, getCurrentUserProfile)
│   ├── favorito_supabase_service.dart # Supabase favoritos CRUD (getFavoritosIds, addFavorito, removeFavorito, isFavorito)
│   ├── favorito_service.dart     # SharedPreferences legacy (NO usado por providers)
│   ├── visita_service.dart       # Supabase visitas CRUD + joins + _actualizarCache (promedio en destinos) + getResumenCalificacionesForDestinos
│   ├── storage_service.dart      # Supabase Storage (uploadImage/uploadImageWeb, uploadAvatar/uploadAvatarWeb con upsert, deleteImage, bucket auto-creation)
│   ├── weather_service.dart      # OpenWeatherMap API (getWeather, timeout 15s)
│   ├── geocoding_service.dart    # Photon API (geocode con fallback sin provincia, timeout 30s, filtro EC)
│   ├── gps_service.dart          # geolocator GPS (getCurrentLocation con timeout 15s + fallback lastKnown)
│   ├── overpass_service.dart     # Overpass API (buscarSitiosCercanos radio 5km, POST fallback GET, timeout 25s, top 10)
│   └── snackbar_service.dart     # Snackbars con mostrarExito/mostrarAdvertencia/mostrarError + _mensajeAmigable (AuthException, PostgrestException, StorageException, SocketException, maps, clima, avatar, ubicación, timeout, cámara)
└── widgets/
    ├── destino_card.dart         # Card resumen con imagen, categoría badge, distancia badge, corazón fav, nombre, creador, calificación, ClimaResumen, onDataChanged callback
    ├── destino_card_editable.dart# Card con editar/eliminar overlays oscuros + imagen + fav + info + ClimaResumen
    ├── destino_osm_card.dart     # Card horizontal Overpass (tipo icono, nombre, distancia, botón "Agregar" → AddDestinoScreen)
    └── clima_resumen.dart        # Widget clima reusable (3 columnas: clima, temperatura, humedad)
```

---

## 10. Flujo de Datos Clave

### Crear un Destino
1. Usuario llena formulario en `AddDestinoScreen` (nombre, provincia [Autocomplete], categoría [Autocomplete], descripción)
2. Al llenar nombre y provincia, **auto-geocoding con debounce 800ms** → `GeocodingService.geocode()` → si ya hay coordenadas, solo `WeatherService.getWeather()`. El usuario también puede ingresar coordenadas manualmente.
3. `_dispararSiCompleto()` decide si obtiene ubicación+yclima o solo clima.
4. Selecciona imagen (galería, web o móvil, límite 1 MB) → `StorageService.uploadImage()` o `uploadImageWeb()` → URL pública
5. Guarda → inserta/update en Supabase `destinos` via cliente directo con `.eq('uid', user.id)` para seguridad
6. Retorna `true` a la pantalla anterior → recarga

### Editar un Destino
1. Dueño toca icono editar en AppBar de `DestinoDetailScreen` → `AddDestinoScreen(destinoToEdit: destino)` **o edita desde `DestinoCardEditable` en ProfileScreen**
2. Formulario pre-llenado con datos actuales. Imagen existente se muestra y puede reemplazarse.
3. Al guardar: `supabase.from('destinos').update().eq('id', destino.id).eq('uid', user.id)`
4. `DestinoDetailScreen._recargarDestino()` recarga el destino desde Supabase (preserva `nombreCreador`)
5. `DestinoDetailScreen` llama a `DestinoUpdateNotifier.notify()` Y `FavoritoProvider.refreshDestinosFavoritos()` → incrementa `_ultimaModificacionDestinos`
6. HomeScreen y FavoritesScreen detectan el cambio vía `DestinoUpdateNotifier.version` y/o `ultimaModificacionDestinos` y recargan

### Calificar un Destino
1. Usuario va a `DestinoDetailScreen`
2. Toca icono `reviews_rounded` en AppBar (si no ha calificado) o "Editar" en su reseña existente
3. Selecciona estrellas (AppColors.sol, con etiqueta: Muy malo/Malo/Regular/Bueno/Excelente), opcionalmente escribe comentario
4. `VisitaProvider.addVisita(nombreUsuario)` o `updateVisita()` → `VisitaService.createVisita/updateVisita()` → inserta/update en Supabase `visitas`
5. `VisitaService._actualizarCache()` actualiza `promedio_calificacion` y `total_calificaciones` en tabla `destinos`
6. Provider recalcula promedio y actualiza UI. Fechas se muestran en formato relativo ("Hace 2 días").

### Eliminar una Reseña
1. Usuario toca "Eliminar" en su reseña → diálogo de confirmación (AppColors.musgo)
2. `VisitaProvider.deleteVisita()` → `VisitaService.deleteVisita()` → delete en Supabase
3. Provider recalcula promedio y actualiza `_totalVisitas`

### Eliminar Destino (desde Perfil)
1. Dueño toca basurero en `DestinoCardEditable` (ProfileScreen) → diálogo confirmación
2. `_eliminarDestino()` → Supabase delete con `.eq('id', id).eq('uid', user.uid)`
3. `_onDestinoChanged()` invalida cache, recarga local, **y notifica globalmente** (`DestinoUpdateNotifier.notify()` + `FavoritoProvider.refreshDestinosFavoritos()`)
4. HomeScreen y FavoritesScreen se refrescan automáticamente

### Favoritos
1. Usuario toca corazón en `DestinoCard` (Home/Favorites) o en AppBar de `DestinoDetailScreen`
2. `FavoritoProvider.toggleFavorito()` → `FavoritoSupabaseService.addFavorito/removeFavorito()` → Supabase tabla `favoritos`
3. **`addFavorito()` y `removeFavorito()` incrementan `_ultimaModificacionDestinos` y llaman `notifyListeners()`**
4. Provider actualiza listas internas (`_favoritosIds` y `_destinosFavoritos`) y notifica
5. UI se re-renderiza (corazón lleno/vacío). **HomeScreen y FavoritesScreen detectan cambio en `ultimaModificacionDestinos` y recargan sus listas automáticamente**

### Cerca de mí (ordenar por distancia + Overpass)
1. Usuario toca icono `my_location_rounded` en AppBar de HomeScreen
2. Si ya activo (guard de 2s contra misclick): se desactiva, restaura orden original
3. Si no activo: `GpsService.getCurrentLocation()` → obtiene posición GPS (timeout 15s, fallback lastKnown)
4. Destinos se ordenan por distancia ascendente (Haversine) y muestran badge "X.X km" o "XXX m"
5. `OverpassService` consulta lugares turísticos cercanos en OSM (radio 5km, caché 10s)
6. Sección "También cerca de ti" aparece con cards horizontales (`DestinoOsmCard` con icono según tipo)
7. Cada card tiene botón "Agregar" → `AddDestinoScreen` con nombre y coordenadas pre-llenados + clima automático
8. Estado persiste al cambiar de tabs (IndexedStack)

### Avatar (foto de perfil)
1. Usuario toca avatar en `ProfileScreen`
2. Bottom sheet: cámara o galería → `ImagePicker.pickImage()` (max 1024x1024)
3. `StorageService.uploadAvatar()` o `uploadAvatarWeb()` → bucket `avatars` (upsert por uid, 2 MB límite) con timestamp anti-caché
4. `SessionProvider.updateAvatar()` → `AuthService.updateUserProfile(avatarUrl)` → actualiza `avatar_url` en tabla `users`
5. Recarga perfil y muestra nueva foto. Manejo de errores separado: `(upload)` vs `(db)` para mensajes específicos.

### HomeScreen — Filtros (Bottom Sheet)
1. Usuario toca `tune_rounded` en AppBar o "Más" junto a chips de categoría
2. `_FiltrosBottomSheet` se abre como DraggableScrollableSheet (82% altura inicial)
3. 3 secciones: Categoría (checkboxes con "Ver más"), Provincia (con búsqueda + "Ver más"), Calificación mínima (estrellas)
4. Al aplicar, `_categoriaFiltro`, `_provinciaFiltro`, `_minRating` se actualizan
5. Chips activos se muestran bajo la barra de categorías con opción de eliminar individualmente
6. Badge en AppBar muestra conteo de filtros activos

### HomeScreen — Paginación
1. Carga inicial: 20 destinos (`_pageSize=20`) con `range(0, 19)`
2. ScrollListener detecta cuando `pixels >= maxScrollExtent - 200` y carga página siguiente
3. `_currentPage` se incrementa, `_hasMore` se actualiza según si response.length == pageSize
4. Cada lote también resuelve `nombre_creador` desde tabla `users`

### ProfileScreen — Dashboard
1. Al cargar perfil, `_cargarMisDestinos()` obtiene destinos del usuario + llama a `VisitaService.getResumenCalificacionesForDestinos()`
2. Dashboard muestra: conteo de destinos y reseñas, gráfico de barras horizontales (desglose 5★ a 1★ con barras de colores y conteo), promedio general con estrella
3. Badge "Explorador" si el usuario tiene ≥3 destinos
4. Secciones de "Categorías" y "Provincias" con chips
5. Caché de recarga: solo recarga si pasaron >3s desde la última carga

---

## 11. Decisiones de Diseño

- **Favoritos en Supabase:** Los favoritos se almacenan en la tabla `favoritos` de Supabase, sincronizados entre sesiones del mismo usuario. Cada favorito vincula `uid` con `destino_id`. SharedPreferences (`FavoritoService` legacy) ya no se usa para favoritos.
- **Calificaciones con cache desnormalizado:** El promedio se calcula en tiempo real desde `visitas`, pero `VisitaService._actualizarCache()` escribe `promedio_calificacion` y `total_calificaciones` en la tabla `destinos` para evitar joins costosos en listas.
- **Geocoding con Photon (OSM):** Gratuito, sin API key, basado en OpenStreetMap. Encuentra ciudades, parques nacionales, y puntos de interés en Ecuador. Timeout 30s. Fallback automático sin provincia si la primera consulta falla.
- **Auto-geocoding con debounce:** Al crear/editar un destino, geocoding + clima se disparan automáticamente 800ms después de que el usuario llena nombre y provincia. Sin botón manual. Si ya hay coordenadas (modo edición o OSM), solo obtiene clima.
- **Autocomplete en lugar de DropdownMenu:** Provincia y categoría usan `Autocomplete` de Material en vez de `DropdownMenu` con búsqueda. El widget `Autocomplete` filtra mientras escribe y permite navegación con teclado.
- **Avatar en bucket separado (`avatars`):** Bucket público con upsert por uid, manejo de errores separado (upload vs db) con mensajes específicos. Timestamp anti-caché en URL.
- **Búsqueda insensible a acentos:** Tanto en Home como en Favoritos, la búsqueda normaliza á→a, é→e, etc., para encontrar "Cafe" al buscar "Café".
- **"Cerca de mí" opt-in:** El usuario activa manualmente tocando `my_location_rounded` en AppBar. No se activa automáticamente. Ordena destinos por distancia GPS y carga Overpass. El estado persiste al cambiar de tabs gracias a IndexedStack.
- **Overpass API solo consulta:** Los resultados de Overpass NO se agregan a Supabase automáticamente. Se muestran en sección separada "También cerca de ti" con botón "Agregar" que pre-llena el formulario de nuevo destino. Caché de 10s entre consultas para evitar rate limiting.
- **IndexedStack en tabs:** MainTabsScreen usa `IndexedStack` en vez de switch simple para preservar el estado de cada pantalla (scroll, filtros, "Cerca de mí", resultados Overpass) al cambiar entre tabs.
- **Haversine inline:** El cálculo de distancia entre coordenadas se implementa como función inline con `dart:math`, sin dependencias externas.
- **Rate limit y guard de misclick:** Las consultas a Overpass tienen un caché mínimo de 10s. El toggle de "Cerca de mí" ignora taps si pasaron menos de 2s del último toggle.
- **Paginación con ScrollController:** HomeScreen carga 20 destinos por página con scroll infinito. Detecta `maxScrollExtent - 200` para gatillar carga. Incluye indicador de carga al final.
- **Filtros BottomSheet con progresividad:** Los filtros de categoría y provincia muestran solo 6 opciones inicialmente con enlace "Ver más (N)". Incluye búsqueda en provincia. La calificación mínima usa estrellas interactivas.
- **AppColors como paleta fija:** Sin colores generados por `fromSeed` que introducían tintes morados en dropdowns. Se forza `canvasColor`, `surfaceContainerHigh`, y `menuTheme` a blancos para coherencia visual. Paleta de 11 colores (sol, solOscuro, solClaro, tinta, musgo, musgoClaro, lienzo, lienzoAlterno, niebla, error, exito).
- **Diálogos consistentes:** Todos los botones de acción destructiva usan `AppColors.musgo` (gris) en vez de rojo. Cancelar hereda `AppColors.sol` del `TextButtonTheme`.
- **Botones de reseña:** Cancelar como `OutlinedButton`, Publicar como `FilledButton` — ambos con el mismo tamaño (flex:1).
- **SnackbarService centralizado:** Traduce excepciones técnicas (`AuthException`, `PostgrestException`, `SocketException`, etc.) a mensajes amigables en español, sin exponer detalles internos. Incluye detección específica para errores de avatar (`(upload)` y `(db)`), ubicación, clima, mapas, cámara/galería, y timeout.
- **Provider + ChangeNotifier:** Elección pragmática para app pequeña/mediana. No se requiere Bloc, Riverpod, o Redux.
- **Botones de acción en cards:** Editar/eliminar en `DestinoCardEditable` usan overlays semitransparentes oscuros (consistente con badge de categoría) en vez de círculos blancos.
- **AppBar de dueño:** En `DestinoDetailScreen`, si el usuario es dueño del destino, aparecen iconos de editar y eliminar en la AppBar como `_CircleIconButton` blancos.
- **Etiquetas de calificación:** Bajo las estrellas del formulario de reseña se muestra etiqueta textual: "Muy malo", "Malo", "Regular", "Bueno", "Excelente".
- **Fecha relativa en reseñas:** Las reseñas muestran "Hace X días/horas/minutos" en vez de fecha absoluta.
- **Formulario contextual de reseña:** El título del formulario cambia entre "Comparte tu experiencia" (nueva) y "Editar tu reseña" (existente). El botón cambia entre "Publicar reseña" y "Actualizar reseña".
- **PopScope en detalle:** `DestinoDetailScreen` usa `PopScope` (con `onPopInvokedWithResult`) para devolver `_dataModificada` a la pantalla anterior, permitiendo recarga condicional.
- **Bar Chart en perfil:** Dashboard de perfil incluye gráfico de barras horizontales con barras de colores (verde, naranja, gris, rojo) mostrando desglose de reseñas de 5★ a 1★, junto con tarjeta de promedio general.
- **Caché de recarga en perfil:** `ProfileScreen` solo recarga destinos si pasaron >3s desde la última carga, evitando ciclos infinitos con `context.watch`.
- **Botpress con JavaScript Bridge:** El chatbot embebido usa `addJavaScriptChannel('BotpressBridge')` para escuchar eventos `ready` y `closed`. Un `MutationObserver` oculta el launcher flotante de Botpress. El script de configuración del bot se carga desde `files.bpcontent.cloud`.
- **Uso de `withValues(alpha:)`:** En lugar de `withOpacity()` (obsoleto en Flutter 3.44+), se usa `withValues(alpha:)` para transparencias.
- **Recarga post-edit en HomeScreen/FavoritesScreen:** `DestinoDetailScreen._recargarDestino()` recarga el destino individual. `FavoritoProvider.refreshDestinosFavoritos()` incrementa `_ultimaModificacionDestinos` que es observado por HomeScreen y FavoritesScreen para recargar automáticamente. Adicionalmente, `DestinoUpdateNotifier` (notificador ligero con contador de versiones) se dispara para asegurar recarga incluso si el mecanismo de favoritos no detecta el cambio.
- **Seguridad en updates:** Tanto update como delete de destinos usan `.eq('uid', session.user!.uid)` para evitar que un usuario modifique destinos ajenos.
- **States de UI separados:** HomeScreen distingue entre "No hay destinos disponibles" (empty state global) y "Sin resultados" (búsqueda/filtros sin match). FavoritesScreen distingue entre "No tienes favoritos todavía" y "Sin resultados".
- **Auto-refresh global unificado:** Se eliminó el listener problemático en `ProfileScreen.build()` que causaba bucle infinito. Ahora `_onDestinoChanged()` (llamado tras crear/editar/eliminar en Perfil) notifica explícitamente a `DestinoUpdateNotifier` y `FavoritoProvider.refreshDestinosFavoritos()`. HomeScreen y FavoritesScreen siguen escuchando sus notificadores propios. Esto evita loops y garantiza propagación unidireccional.
- **Scroll fluido en ProfileScreen:** Se eliminó el `Column` anidado dentro de `SingleChildScrollView` + `RefreshIndicator` que bloqueaba el scroll. Ahora usa `RefreshIndicator` + `SingleChildScrollView` con children directos (`_buildDashboard()`, `SizedBox(8)`, `_buildMisDestinosSection()`).
- **Logout button fijo en header:** El botón de cerrar sesión se movió de un `Positioned(top: 150)` flotante (que se quedaba en pantalla al hacer scroll) al header del perfil, junto al botón de cámara del avatar. Ahora está en la esquina superior derecha del avatar y no flota.
- **Padding reducido en "Mis destinos":** Se eliminó el `SizedBox(height: 4)` entre el header "Mis destinos" y la primera card, usando el margin natural de la card (`margin: EdgeInsets.only(bottom: 16)`) para espaciado consistente.
- **FavoritoProvider version increment en add/remove:** `addFavorito()` y `removeFavorito()` ahora incrementan `_ultimaModificacionDestinos` para que HomeScreen y FavoritesScreen se refresquen automáticamente al tocar el corazón, sin requerir `refreshDestinosFavoritos()` manual.

---

## 12. Seguridad

- **Supabase publishable key** expuesta en cliente (es el diseño de Supabase — RLS policies protegen los datos).
- **No se exponen mensajes de error internos** — `SnackbarService` traduce a mensajes genéricos.
- **Autenticación:** Solo email/password. No hay 2FA ni magic links.
- **Storage:** Imágenes subidas al bucket `destinos` con políticas RLS (asumidas). Bucket `avatars` público con upsert.
- **Aleatoriedad:** Al registrarse se genera un nombre aleatorio de 8 dígitos si no se proporciona uno.
- **Eliminación segura:** Solo el dueño (`uid`) puede eliminar sus destinos (filtro `.eq('uid', session.user!.uid)` tanto en delete como en update).

---

## 13. Próximas Mejoras Potenciales

- Soporte offline (Hive/Isar para datos locales).
