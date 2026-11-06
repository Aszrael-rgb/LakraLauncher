# Lakra Launcher

Launcher ligero para Windows construido en Flutter. Lakra presenta una biblioteca de juegos con filtros reactivos, carátulas, detalles y controles de lanzamiento, además de ajustes de inicio y acceso desde la bandeja del sistema.

## Requisitos y paquetes

- Flutter stable con soporte Windows, Dart 3.11 o posterior y Visual Studio Build Tools con C++.
- `flutter_riverpod: ^2.6.1` para estado y ajustes.
- `window_manager: ^0.5.2` para gestionar la ventana personalizada del launcher.
- `tray_manager: ^0.5.3` para el icono de bandeja y la opción de salida.
- `url_launcher: ^6.3.2` para protocolos Steam y Epic.
- `shared_preferences: ^2.5.5` para guardar la biblioteca manual entre ejecuciones.
- `path_provider: ^2.1.6` para datos de soporte de la aplicación.
- `win32: ^6.4.0` y `ffi: ^2.2.0` para habilitar el inicio automático del usuario en Windows.

Las restricciones exactas están en `pubspec.yaml` y las versiones resueltas en `pubspec.lock`.

## Desarrollo

```powershell
flutter pub get
flutter run -d windows
```

Para comprobar y empaquetar:

```powershell
flutter analyze
flutter test
flutter build windows
```

La ventana principal usa una barra de título personalizada con controles para minimizar, maximizar y ocultar. Cerrar la ventana la oculta en la bandeja; al hacer clic en el icono se vuelve a mostrar. El menú contextual de la bandeja ofrece la opción de salir.

En una instalación nueva, Lakra añade su ejecutable a la clave `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run`. El ajuste de inicio automático se puede cambiar desde la pestaña **Ajustes** y se conserva en las preferencias y en el servicio de Windows. Lakra requiere permisos de administrador: Windows muestra UAC al iniciar la aplicación (también al iniciar sesión si el inicio automático está activado). Los ejecutables iniciados directamente heredan esos permisos.

## Catálogo y lanzamiento

- Steam: busca `appmanifest_*.acf` en las bibliotecas predeterminadas y las rutas listadas por `libraryfolders.vdf`; lanza `steam://rungameid/<appid>`.
- Epic Games: lee manifiestos JSON `.item` bajo `%PROGRAMDATA%\Epic\EpicGamesLauncher\Data\Manifests` y abre el protocolo de Epic.
- EA app, GOG, Battle.net y Rockstar Games: Lakra consulta las claves de registro de Windows de cada plataforma, resuelve ejecutables instalados y los inicia directamente.
- Custom: busca `.exe`, `.lnk`, `.url`, `.bat` y `.cmd` en `%USERPROFILE%\LakraLauncher\Custom`. Configura `LAKRA_CUSTOM_DIR` para cambiar esa ruta.
- La biblioteca permite filtrar por nombre y etiquetas, alternar entre cuadrícula y lista, consultar detalles e iniciar los juegos detectados. Los filtros de proveedor buscan el nombre de la fuente en las etiquetas de los juegos.
- Juegos manuales: el almacenamiento local y las operaciones de añadir/quitar se conservan en los servicios, pero no hay una interfaz para gestionarlos.

El escaneo es asíncrono y omite archivos o carpetas inaccesibles o sin una ruta de ejecutable verificable. La detección de EA app, GOG, Battle.net y Rockstar depende de que sus claves de registro expongan la ruta del juego o su ejecutable; las instalaciones no registradas se pueden añadir manualmente. Los `.exe` y emuladores se inician con `Process.start` detached y heredan el token elevado de Lakra; los `.lnk`, `.url`, `.bat` y `.cmd` se abren mediante el shell de Windows desde el proceso elevado. Los juegos de Steam y Epic se solicitan mediante sus protocolos: si Steam o Epic ya estaban abiertos sin elevación, ciérralos; al iniciar el juego desde Lakra, sus launchers podrán abrirse elevados y sus juegos heredar esos permisos. No se puede suprimir UAC de forma segura: la confirmación es al iniciar Lakra, no por cada juego. Añade únicamente `.bat` y `.cmd` de confianza, porque se ejecutan con permisos de administrador.

## Metadatos de juegos

Lakra busca automáticamente en la tienda pública de Steam el nombre, el ID
de la aplicación y la carátula oficial `header_image`, usando el idioma español
y la región ES. No hace falta configurar cuentas, claves ni credenciales. Si
Steam no encuentra una coincidencia o no responde, la biblioteca local sigue
disponible y se conservan las portadas personalizadas.
