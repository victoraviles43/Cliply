# Portapapeles para macOS

Una app de barra de menús que muestra los últimos 10 elementos copiados con **Control + Espacio**. Admite texto, imágenes y archivos. Al seleccionar uno, lo vuelve a poner en el portapapeles; usa **Comando + V** para pegarlo en la app donde estabas.

El panel tiene dos pestañas: **Portapapeles** y **Emojis**. La pestaña de emojis incluye categorías y búsqueda; al elegir uno, queda listo para pegar y también aparece en el historial.

Puedes **anclar** cualquier elemento con la chincheta de su tarjeta. Los anclados se muestran primero y se conservan al borrar los recientes. Se guardan hasta 10 elementos **sin anclar**; al copiar uno más, se elimina el más antiguo de ese grupo. El menú de tres puntos de cada tarjeta permite anclar, desanclar o eliminar ese elemento.

Todo el historial, incluidos los anclados, vive en memoria durante la sesión de la app. Se pierde al cerrarla. Si vuelves a copiar un elemento existente, este sube al principio de su grupo.

## Compilar y ejecutar

Requiere macOS 14 o posterior y Xcode con las herramientas de línea de comandos.

```sh
./build-app.sh
open dist/Portapapeles.app
```

La app aparece como un icono de portapapeles en la barra de menús. Puedes abrir el historial desde ese icono si **Control + Espacio** ya está asignado a otra función del sistema. En ese caso, cambia el atajo que entra en conflicto en **Ajustes del Sistema > Teclado > Atajos de teclado** y vuelve a iniciar la app.

Para abrirla automáticamente al iniciar sesión, añádela en **Ajustes del Sistema > General > Ítems de inicio**.
