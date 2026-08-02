# Fardo · Panel de tienda de ropa

Aplicación interna en español para gestionar inventario, variantes, ventas, ganancias y usuarios de una tienda de ropa.

## Stack

- React + Vite
- Tailwind CSS
- Supabase Database, Auth y Storage

## Ejecutar localmente

Requisitos: Node.js 20+ y pnpm.

```powershell
pnpm install
Copy-Item .env.example .env.local
pnpm dev
```

Configura en `.env.local` las variables de tu proyecto de Supabase:

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxxx
```

> `.env.local` está ignorado por Git. Nunca incluyas una clave `service_role` ni contraseñas en el repositorio.

## Base de datos de Supabase

Ejecuta las migraciones en este orden desde el SQL Editor de Supabase:

1. `supabase/migrations/20260802170000_tienda_ropa.sql`
2. `supabase/migrations/20260802185500_endurecer_funciones.sql`
3. `supabase/migrations/20260802193000_productos_con_variantes.sql`
4. `supabase/migrations/20260802195000_permitir_verificar_rol.sql`

Las migraciones crean las tablas, las políticas RLS, el bucket privado de imágenes y el flujo de ventas con variantes.

## Publicar en GitHub

El proyecto ya está preparado para versionarse. Cuando crees un repositorio vacío en GitHub, ejecuta:

```powershell
git add .
git commit -m "feat: panel de inventario y ventas"
git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
git push -u origin main
```

## Hosting posterior

Para desplegar en Vercel, Netlify o Cloudflare Pages usa estos valores:

- Comando de compilación: `pnpm build`
- Directorio de publicación: `dist`
- Variables de entorno: `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`

Añade esas variables desde el panel del proveedor de hosting; no subas `.env.local`.

## Verificación

```powershell
pnpm build
```
