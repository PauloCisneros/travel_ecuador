# Travel Ecuador 🇪🇨

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)

**Travel Ecuador** es una aplicación móvil desarrollada en Flutter diseñada para descubrir, compartir y guardar destinos turísticos en Ecuador. Los usuarios pueden explorar lugares de interés, obtener datos climáticos en tiempo real, visualizar mapas interactivos, y participar en la comunidad calificando y dejando reseñas.

---

## 🌟 Características Principales

### 🚀 Exploración y Autenticación
Descubre destinos ecuatorianos y crea tu perfil personalizado.

<div align="center">
  <img src="capturas/splash_screem.jpeg" width="200" alt="Splash Screen" />
  <img src="capturas/login.jpeg" width="200" alt="Login" />
  <img src="capturas/home.jpeg" width="200" alt="Home" />
</div>

### 🔍 Filtros y Favoritos
Encuentra exactamente lo que buscas filtrando por categoría, provincia o calificación, y guarda tus destinos favoritos.

<div align="center">
  <img src="capturas/filtros.jpeg" width="200" alt="Filtros" />
  <img src="capturas/favoritos.jpeg" width="200" alt="Favoritos" />
</div>

### 📍 Ubicación y Clima en Tiempo Real
La aplicación utiliza el GPS de tu dispositivo para encontrar lugares "Cerca de mí" y muestra el clima actual del destino seleccionado.

<div align="center">
  <img src="capturas/modo_cerca_de_mi.jpeg" width="200" alt="Modo cerca de mí" />
  <img src="capturas/detail_lugar.jpeg" width="200" alt="Detalle del Lugar" />
</div>

### ✏️ Gestión de Destinos y Perfil
Añade nuevos lugares a la plataforma, edita tus contribuciones y gestiona tu perfil con un panel de estadísticas de tus interacciones y reseñas.

<div align="center">
  <img src="capturas/form_añadir_lugar.jpeg" width="200" alt="Añadir Lugar" />
  <img src="capturas/editarform_lugar.jpeg" width="200" alt="Editar Lugar" />
  <img src="capturas/perfil.jpeg" width="200" alt="Perfil" />
</div>

### 🤖 EcuGuía: Asistente Turístico
Interactúa con nuestro chatbot inteligente integrado (impulsado por Botpress) para obtener recomendaciones y asistencia sobre turismo local.

<div align="center">
  <img src="capturas/chatbot.jpeg" width="200" alt="Chatbot" />
</div>

---

## 🛠️ Stack Tecnológico

- **UI Framework:** Flutter (Material 3)
- **Gestión de Estado:** `provider` + ChangeNotifier
- **Backend & Autenticación:** Supabase (Auth, Postgres DB, Storage)
- **Mapas y Geocodificación:** `flutter_map` (OpenStreetMap), `url_launcher`, Photon API
- **Clima:** OpenWeatherMap API
- **Búsqueda de POI:** Overpass API (OpenStreetMap)
- **Geolocalización:** `geolocator`
- **Asistente Virtual:** `webview_flutter` con Botpress embebido

## 📐 Arquitectura

La aplicación sigue el patrón **Service - Provider - Screen**:

1. **Pantallas (UI):** Se suscriben a los Providers usando `context.watch()` o `context.read()` para renderizar la interfaz.
2. **Providers:** Manejan el estado de la aplicación de manera global (`SessionProvider`, `FavoritoProvider`, `VisitaProvider`, `DestinoUpdateNotifier`) y notifican a la UI de los cambios en tiempo real.
3. **Servicios:** Clases que encapsulan la lógica de negocio pura y las llamadas a dependencias externas (Supabase, API de Clima, Photon, OSM, GPS, etc.).

## 🚀 Empezando (Getting Started)

### Requisitos Previos
- Flutter SDK `^3.12.1`

### Instalación

1. Clona el repositorio
2. Instala las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

*(Nota: La aplicación contiene las credenciales de conexión de desarrollo y APIs. Para un ambiente de producción, se recomienda reemplazarlas por llaves propias).*

## 📂 Estructura del Proyecto

```text
lib/
├── main.dart             # Punto de entrada y MultiProvider
├── splash_screen.dart    # Pantalla de carga con animación custom
├── models/               # Modelos de datos (Destino, User, Visita, Categorías, Provincias)
├── providers/            # Notificadores de estado (Auth, Favoritos, Visitas)
├── screens/              # Vistas principales (Home, Auth, Profile, Detail, etc.)
├── services/             # Conexiones externas (Supabase, Weather, Gps, Geocoding)
├── theme/                # Configuración de tema global (Material 3 y Paleta de colores)
├── utils/                # Funciones utilitarias (Cálculo Haversine para distancias, Caché)
└── widgets/              # Componentes reutilizables (Cards, Resumen de Clima)
```
