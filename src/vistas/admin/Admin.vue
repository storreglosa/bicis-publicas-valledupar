<script setup>
// Marco del panel de administración: menú y área de contenido (rutas hijas).
// La seguridad real está en la base: cada consulta y función vuelve a exigir el
// rol de administrador (RLS + privado.exigir_rol).
const secciones = [
  { a: '/admin', titulo: 'Tablero', exacta: true },
  { a: '/admin/bicicletas', titulo: 'Bicicletas' },
  { a: '/admin/puntos', titulo: 'Puntos y eventos' },
  { a: '/admin/personas', titulo: 'Personas' },
  { a: '/admin/prestamos', titulo: 'Préstamos' },
  { a: '/admin/personal', titulo: 'Personal' },
  { a: '/admin/parametros', titulo: 'Parámetros' },
  { a: '/admin/auditoria', titulo: 'Auditoría' },
  { a: '/admin/etiquetas', titulo: 'Etiquetas QR' },
  { a: '/admin/politicas', titulo: 'Política de datos' },
]
</script>

<template>
  <div class="admin contenedor">
    <nav class="admin__menu" aria-label="Administración">
      <ul>
        <li v-for="s in secciones" :key="s.a">
          <RouterLink :to="s.a" :exact-active-class="s.exacta ? 'activo' : ''" :active-class="s.exacta ? '' : 'activo'">{{ s.titulo }}</RouterLink>
        </li>
      </ul>
    </nav>
    <div class="admin__contenido">
      <RouterView />
    </div>
  </div>
</template>

<style scoped>
.admin { padding-block: var(--esp-4) var(--esp-6); }
.admin__menu ul { list-style: none; margin: 0 0 var(--esp-5); padding: 0; display: flex; flex-wrap: wrap; gap: var(--esp-2); }
.admin__menu a {
  display: inline-flex; align-items: center; min-height: 40px; padding: 0 var(--esp-3);
  border: 2px solid var(--linea-fuerte); border-radius: 999px; color: var(--tinta-1); text-decoration: none; font-weight: 600;
  font-size: var(--texto-s); background: var(--superficie);
}
.admin__menu a.activo { background: var(--tinta-1); border-color: var(--tinta-1); color: var(--superficie); }
.admin__menu a:hover { border-color: var(--primario); }
</style>

<style>
/* Utilidades comunes de las vistas de administración */
.admin-cabeza { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: end; gap: var(--esp-3); margin-bottom: var(--esp-4); }
.admin-cabeza h1 { margin: 0; }
.admin-cabeza p { margin: var(--esp-1) 0 0; color: var(--tinta-2); }
.tabla-admin { width: 100%; border-collapse: collapse; background: var(--superficie); font-size: var(--texto-s); }
.tabla-admin th, .tabla-admin td { text-align: left; padding: var(--esp-2) var(--esp-3); border-bottom: 1px solid var(--linea); vertical-align: top; }
.tabla-admin th { background: var(--banda); font-weight: 650; position: sticky; top: 0; }
.tabla-admin tbody tr:hover { background: var(--fondo); }
.tabla-desplazable { overflow-x: auto; border: 1px solid var(--linea); border-radius: var(--radio-m); margin-bottom: var(--esp-4); }
.filtros { display: flex; flex-wrap: wrap; gap: var(--esp-3); align-items: end; margin-bottom: var(--esp-4); }
.filtros .campo { margin-bottom: 0; min-width: 10rem; }
.boton--pequeno { min-height: 36px; padding: 0 var(--esp-3); font-size: var(--texto-s); }
/* El resultado de una acción sigue a la vista aunque el usuario esté al final de una lista larga. */
.admin__contenido > section > .mensaje { position: sticky; top: var(--esp-2); z-index: 2; box-shadow: var(--sombra); }
.vacio { color: var(--tinta-2); padding: var(--esp-4) 0; }
</style>
