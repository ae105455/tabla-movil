# API REST y base de datos

## Investigación

La aplicación Flutter usa HTTP para comunicarse con una API REST en PHP. La API valida los datos y utiliza PDO con consultas preparadas para guardar las evaluaciones en MySQL. Flutter no se conecta directamente al servidor MySQL: la API es la capa que protege las credenciales y expone operaciones controladas.

| Operación CRUD | Método HTTP | Uso |
| --- | --- | --- |
| Leer | GET | Devuelve las evaluaciones existentes. |
| Crear | POST | Inserta una evaluación y devuelve su identificador. |
| Actualizar | PUT | Modifica la evaluación indicada por `id`. |
| Eliminar | DELETE | Elimina la evaluación indicada por `id`. |

## Puesta en marcha

Requisitos: PHP 8 o posterior con las extensiones `pdo_mysql` y `mbstring`, y MySQL 8.0.16 o posterior.

1. Crea la base y la tabla ejecutando `mysql -u root -p < backend/database.sql`.
2. Configura `MYSQL_HOST`, `MYSQL_DATABASE`, `MYSQL_USER` y `MYSQL_PASSWORD` en el entorno del servidor PHP. Los valores predeterminados son `127.0.0.1`, `tabla_movil`, `root` y contraseña vacía; configura un usuario y contraseña propios fuera de una instalación local de prueba.
3. Desde la raíz del proyecto, inicia el servidor de desarrollo con `php -S 0.0.0.0:8000 -t backend`.
4. Inicia Flutter indicando dónde está la API:

```sh
flutter run --dart-define=API_URL=http://localhost:8000/api/evaluaciones.php
```

En el emulador Android estándar, usa `http://10.0.2.2:8000/api/evaluaciones.php`. En un teléfono físico, usa la dirección IP local del equipo que ejecuta PHP y asegúrate de que ambos estén en la misma red. Para Flutter Web, el endpoint debe ser accesible desde el navegador; la API permite CORS para facilitar la prueba local.

En la pantalla, pulsa **Cargar desde MySQL** para leer registros. El icono de guardar crea (POST) una fila nueva o actualiza (PUT) una existente; el icono de eliminar ejecuta DELETE después de confirmar.

## Usar XAMPP y phpMyAdmin

El bloque SQL queda guardado en `backend/database.sql`; puedes abrirlo como texto y pegarlo en phpMyAdmin, o importarlo directamente. No hace falta volver a escribirlo si cierras el programa.

1. Abre XAMPP y enciende **Apache** y **MySQL**.
2. Entra a `http://localhost/phpmyadmin`, abre la pestaña **SQL** y pega todo el contenido de `backend/database.sql`. Pulsa **Continuar** o **Ejecutar**. También puedes seleccionar **Importar** y elegir ese archivo SQL.
3. Copia la carpeta `backend` del proyecto dentro de la carpeta `htdocs/tabla-movil/` de XAMPP. La API debe quedar en `htdocs/tabla-movil/backend/api/evaluaciones.php`.
4. Comprueba en el navegador `http://localhost/tabla-movil/backend/api/evaluaciones.php`. Si la instalación está lista, verás una respuesta JSON, inicialmente `{"data":[]}`.
5. Arranca la app apuntando a Apache. En el emulador Android estándar:

```sh
flutter run --dart-define=API_URL=http://10.0.2.2/tabla-movil/backend/api/evaluaciones.php
```

En Flutter Web o escritorio, usa `http://localhost/tabla-movil/backend/api/evaluaciones.php`. En un teléfono físico, sustituye `localhost` por la IP local del equipo con XAMPP, por ejemplo `http://192.168.1.20/tabla-movil/backend/api/evaluaciones.php`; el teléfono y el equipo deben compartir la red y el firewall debe permitir Apache.

XAMPP suele usar MySQL local con usuario `root` y contraseña vacía, que coincide con los valores iniciales de la API. Si cambias esas credenciales, configura `MYSQL_HOST`, `MYSQL_DATABASE`, `MYSQL_USER` y `MYSQL_PASSWORD` en el entorno desde el que se inicia Apache. La extensión `pdo_mysql` y `mbstring` deben estar habilitadas en PHP de XAMPP.

## Evaluación para la entrega del lunes

El CRUD se considera verificado cuando se puede crear una evaluación, recargar la pantalla y verla persistida, editar una calificación y comprobar el cambio, y eliminarla confirmando que ya no aparece al volver a cargar. Cada calificación acepta valores entre 0 y 25; la API y MySQL también validan ese rango. La comunicación HTTP sin cifrar y CORS abierto son solo para desarrollo local: para publicar el sistema, usa HTTPS, limita los orígenes CORS y configura credenciales de base de datos seguras.
