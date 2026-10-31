# Eliminación de cuentas

- Ruta en Flutter y enlace público: `https://www.luia.app/home/profile/delete-account`.
- Android abre la ruta con el App Link ya registrado; Hosting sirve la página HTML del mismo directorio cuando se abre en un navegador.
- Entrar en la URL no ejecuta el borrado. Se requiere inicio de sesión con email/contraseña, confirmación explícita y autenticación de los últimos cinco minutos.
- `deleteMyAccount` toma el UID exclusivamente del token Firebase. Nunca acepta un UID de destino del cliente.
- El servidor elimina el árbol privado del usuario, las copias de sus datos de contacto/notificaciones, sus comentarios y eventos, y sus referencias en eventos y listas ajenas. Los productos utilizados por otras cuentas permanecen sin vínculo con la cuenta eliminada.
- Se eliminan las imágenes de perfil y los archivos de imágenes referenciados que no estén compartidos con otras cuentas. Las cargas históricas en `wish_images/UUID` y `contact_images/UUID` no incluyen propietario: los archivos antiguos que ya no estén referenciados en ningún documento no se pueden atribuir a una cuenta y requieren una limpieza/migración independiente.
- La cuenta Auth se elimina al finalizar. Un fallo anterior permite reintentar; las eliminaciones parciales no se revierten.
- La limpieza recorre colecciones en páginas de 100 documentos para evitar nuevos índices de colección global. El coste crece con los datos de la aplicación; conviene pasar a trabajos asíncronos e índices específicos si el volumen supera el tiempo máximo de nueve minutos.

## Validación local

Desde `functions`:

```powershell
npm run build
node --test test/*.test.cjs
npm run lint
```

Los tests cubren los rechazos de seguridad del callable y el flujo web con peticiones simuladas. Antes de publicar, probar el borrado completo en un proyecto de pruebas con documentos y archivos de dos usuarios, incluyendo referencias compartidas. No ejecutar esta prueba sobre cuentas reales.

## Publicación

Publicar la función nueva, los tres triggers que comprueban cuentas en eliminación y el Hosting:

```powershell
firebase deploy --only functions:deleteMyAccount,functions:syncItemsToGlobalList,functions:onNewContactRequest,functions:onContactRequestStatusUpdate,hosting:landing
```

Distribuir también la nueva versión Flutter para que aparezca el botón del perfil. La web usa la configuración pública de Firebase ya existente en `firebase_options.dart`.
