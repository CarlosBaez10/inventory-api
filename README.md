# Inventory API

API RESTful para manejo de inventario, con autenticación de usuarios y autorización basada en roles.

---

## Configuración Local

Sigue estos pasos para levantar y configurar el proyecto en tu entorno local.

### Requisitos Previos

Asegúrate de tener instalado lo siguiente:

* **Docker Desktop**: Incluye Docker Engine y Docker Compose.

* **Git**: Para clonar el repositorio.

### Pasos de Instalación

1.  **Clona el repositorio:**
    ```bash
    git clone https://github.com/CarlosBaez10/inventory-api.git
    cd inventory-api
    ```
2.  **Crea el archivo de entorno (`.env`):**
    Copia el archivo de ejemplo y crea tu propio `.env`.
    ```bash
    cp .env.example .env
    ```
    Abre el archivo `.env` y asegúrate de que las variables de base de datos (`DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`) y las de Sanctum (`SANCTUM_STATEFUL_DOMAINS`, `APP_URL`) estén configuradas según tu entorno. Para un entorno local, usualmente basta con los valores por defecto que se adaptan a `docker-compose.yml`.

3.  **Construye y levanta los contenedores Docker:**
    Este comando construirá las imágenes Docker y levantará los servicios definidos en `docker-compose.yml` (servidor web Nginx, PHP-FPM, base de datos MariaDB).
    ```bash
    docker compose up -d --build
    ```

4.  **Instala las dependencias de Composer:**
    Ejecuta Composer dentro del contenedor `app` para instalar las dependencias de PHP.
    ```bash
    docker compose exec app composer install
    ```

5.  **Genera la clave de la aplicación:**
    Necesaria para el cifrado de Laravel.
    ```bash
    docker compose exec app php artisan key:generate
    ```

6.  **Ejecuta las migraciones de la base de datos:**
    Esto creará las tablas necesarias, incluyendo la tabla `users` (con la columna `role`) y `products` (y `personal_access_tokens` de Sanctum).
    ```bash
    docker compose exec app php artisan migrate
    ```

7.  **Ejecuta consulta para crear usuario admin:**
    Para el usuario `admin` y necesitas uno, puedes crearlo manualmente en la base de datos:
    ```bash
    # Acceder al shell del contenedor de la base de datos
    docker compose exec db bash
    # Acceder a MySQL/MariaDB
    mysql -u root -p
    # Usar tu base de datos
    USE laravel; # O el nombre de tu BD
    # Crear un usuario existente a admin
    INSERT INTO users (name, email, password, role, created_at, updated_at)
    VALUES (
        'Admin User',
        'admin@example.com',
        '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password es 'password' hasheado
        'admin',
        NOW(),
        NOW()
    );
    # Salir
    exit;
    exit;
    ```

8.  **Permisos de directorio (si es necesario):**
    Si encuentras problemas de permisos con el almacenamiento o caché, esto podría ayudar (Docker Compose ya debería manejarlo si el usuario `www-data` está bien configurado).
    ```bash
    docker compose exec app php artisan storage:link
    docker compose exec app chmod -R 775 storage bootstrap/cache
    ```

Ahora tu API debería estar lista y accesible en `http://localhost`.

---

## Cómo Usar la API (Colección Insomnia)

Para interactuar fácilmente con la API, puedes importar nuestra colección Insomnia.

### Opción 1: Colección Insomnia

1.  **Descargar la Colección:**
    * Descarga el archivo `insomnia.yaml` que esta en este repositorio.
2.  **Importar en Insomnia:**
    * Abre Insomnia.
    * Haz clic en "File" > "Import" (o el botón "Import" en la interfaz).
    * Selecciona el archivo `insomnia.yaml` que descargaste.
    * La colección se importará con todas las rutas y ejemplos de peticiones.

---

## URL Pública de Despliegue

La API está desplegada y accesible públicamente en la siguiente URL:

http://18.231.77.101

---

## Decisiones de Diseño

Aquí se explican las decisiones clave tomadas durante el desarrollo de la API.

### 1. Elección de `ENUM` vs. Tabla de Roles para la Columna `role`

* **Decisión:** Se optó por una columna `ENUM` (`role` en la tabla `users`) con los valores `admin` y `user`.
* **Justificación:**
    * **Simplicidad:** Para un número pequeño y fijo de roles (como `admin` y `user`), un `ENUM` es la solución más sencilla y ligera a nivel de base de datos.
    * **Rendimiento:** Evita joins adicionales a una tabla de roles separada en consultas frecuentes que involucren al usuario.
    * **Coherencia de Datos:** La base de datos aplica una restricción automática, asegurando que solo se puedan asignar los valores definidos (`admin` o `user`), previniendo errores de entrada de datos.
* **Alternativa Considerada (y Por Qué No se Usó):** Una tabla `roles` separada con una relación `many-to-many` (`users` a `roles` a través de una tabla pivote `role_user`). Esto sería preferible para sistemas con un número grande y dinámico de roles que los administradores pudieran crear o modificar en tiempo de ejecución. Para este proyecto, la complejidad adicional no se justificaba.

### 2. Middleware o Paquete de Autorización

* **Decisión:** Se utilizó el **middleware `auth:sanctum`** para la autenticación de tokens de API y las **Policies nativas de Laravel** (`ProductPolicy`) para la autorización basada en roles.
* **Justificación:**
    * **Laravel Sanctum:** Es la solución oficial y recomendada por Laravel para la autenticación de API basada en tokens. Es ligero, fácil de configurar y está optimizado para SPAs y APIs.
    * **Laravel Policies:** Proporcionan una forma estructurada y organizada de definir la lógica de autorización para un modelo específico (ej: `Product`). Permiten centralizar las reglas de negocio de "quién puede hacer qué" de una manera limpia y escalable, usando el método `isAdmin()` del modelo `User`.
    * **Evita Dependencias Externas:** No fue necesario incluir paquetes de terceros para la autorización (como Spatie Laravel-Permission), ya que los requisitos de roles (admin/user) se podían manejar eficientemente con las características propias de Laravel.

### 3. Cambios al Esquema de Base de Datos y Endpoints Originales

* **Esquema de Base de Datos:**
    * **Tabla `users`:** Se añadió una columna `role` (ENUM: `admin` | `user`, por defecto `user`) para la gestión de permisos.
    * **Tabla `products`:** Se creó la tabla `products` con campos básicos como `name`, `description`, `price`, y `stock` para gestionar los elementos del inventario.
* **Endpoints de la API:**
    * **`POST /api/register`**: Permite registrar nuevos usuarios. Si el usuario que realiza la petición es un `admin` autenticado, puede especificar el `role` del nuevo usuario; de lo contrario, se asigna `user` por defecto.
    * **`POST /api/login`**: Permite a los usuarios autenticarse y obtener un token de acceso personal de Sanctum.
    * **`POST /api/logout`**: Permite a los usuarios cerrar sesión, revocando el token actual.
    * **`GET /api/user`**: Devuelve los datos del usuario autenticado.
    * **`GET /api/products`**: Lista todos los productos. Accesible por cualquier usuario autenticado.
    * **`GET /api/products/{id}`**: Muestra un producto específico. Accesible por cualquier usuario autenticado.
    * **`POST /api/products`**: Crea un nuevo producto. **Requiere rol `admin`**.
    * **`PUT/PATCH /api/products/{id}`**: Actualiza un producto existente. **Requiere rol `admin`**.
    * **`DELETE /api/products/{id}`**: Elimina un producto. **Requiere rol `admin`**.
* **Manejo de Errores de API:** Se configuró el `Handler.php` para que todas las respuestas de error (401, 403, 422) en rutas API devuelvan JSON en lugar de redirecciones o HTML, mejorando la experiencia del consumidor de la API.

---