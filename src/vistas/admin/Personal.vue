<script setup>
// Personal: vincular cuentas creadas en Supabase (Authentication → Add user, con
// Auto Confirm User) y gestionar rol y estado. La base impide quedarse sin
// administradores y que un administrador se quite el rol a sí mismo.
import { ref } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { sesion } from '../../lib/sesion.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const { datos, cargando, error, recargar } = useConsulta((sb) =>
  sb.from('personal').select('id,nombre,rol,activo,debe_cambiar_clave,creado_en').order('nombre'))

const nuevo = ref({ correo: '', nombre: '', rol: 'operador' })
const vinculando = ref(false)
const mensaje = ref({ tipo: '', texto: '' })

async function vincular() {
  mensaje.value = { tipo: '', texto: '' }
  vinculando.value = true
  const { error: e } = await supabase.rpc('vincular_personal', {
    p_correo: nuevo.value.correo, p_nombre: nuevo.value.nombre, p_rol: nuevo.value.rol,
  })
  vinculando.value = false
  if (e) {
    mensaje.value = { tipo: 'error', texto: traducirError(e).mensaje }
    return
  }
  mensaje.value = { tipo: 'exito', texto: `${nuevo.value.nombre} quedó vinculado como ${nuevo.value.rol}.` }
  nuevo.value = { correo: '', nombre: '', rol: 'operador' }
  recargar()
}

async function cambiar(p, campo, valor) {
  mensaje.value = { tipo: '', texto: '' }
  const cambio = campo === 'rol' ? { rol: valor } : { activo: valor }
  const { error: e } = campo === 'rol'
    ? await supabase.from('personal').update({ rol: cambio.rol }).eq('id', p.id)
    : await supabase.from('personal').update({ activo: cambio.activo }).eq('id', p.id)
  if (e) mensaje.value = { tipo: 'error', texto: traducirError(e).mensaje }
  recargar()
}
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div>
        <h1>Personal</h1>
        <p>Operadores y administradores con acceso al sistema.</p>
      </div>
    </div>

    <form class="tarjeta-base" @submit.prevent="vincular">
      <h2>Vincular una cuenta</h2>
      <p class="ayuda">Primero crea la cuenta en Supabase: Authentication → Users → Add user, con <em>Auto Confirm User</em>.
        Luego vincúlala aquí. En su primer ingreso deberá cambiar la clave.</p>
      <div class="fila-campos">
        <label class="campo"><span>Correo de la cuenta</span><input v-model="nuevo.correo" type="email" autocomplete="off" /></label>
        <label class="campo"><span>Nombre</span><input v-model="nuevo.nombre" autocomplete="off" /></label>
        <label class="campo"><span>Rol</span>
          <select v-model="nuevo.rol"><option value="operador">Operador</option><option value="administrador">Administrador</option></select></label>
      </div>
      <button class="boton" type="submit" :disabled="vinculando || !nuevo.correo || nuevo.nombre.trim().length < 3">
        {{ vinculando ? 'Vinculando…' : 'Vincular' }}</button>
    </form>

    <p v-if="mensaje.texto" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>
    <p v-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>
    <p v-else-if="cargando">Cargando…</p>
    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Nombre</th><th>Rol</th><th>Estado</th><th>Vinculado</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in datos" :key="p.id">
            <td>{{ p.nombre }}<template v-if="p.id === sesion.perfil?.id"> (tú)</template>
              <br v-if="p.debe_cambiar_clave" /><small v-if="p.debe_cambiar_clave">Debe cambiar la clave</small></td>
            <td>
              <select :value="p.rol" :aria-label="`Rol de ${p.nombre}`" :disabled="p.id === sesion.perfil?.id"
                @change="cambiar(p, 'rol', $event.target.value)">
                <option value="operador">Operador</option><option value="administrador">Administrador</option>
              </select>
            </td>
            <td><span class="etiqueta-estado" :class="p.activo ? 'etiqueta-estado--exito' : 'etiqueta-estado--error'">
              {{ p.activo ? 'Activo' : 'Inactivo' }}</span></td>
            <td>{{ fechaHora(p.creado_en) }}</td>
            <td>
              <button v-if="p.id !== sesion.perfil?.id" class="boton boton--contorno boton--pequeno" type="button"
                @click="cambiar(p, 'activo', !p.activo)">{{ p.activo ? 'Desactivar' : 'Activar' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
h2 { margin-top: 0; font-size: var(--texto-m); }
.ayuda { color: var(--tinta-2); font-size: var(--texto-s); }
.mensaje { margin-bottom: var(--esp-4); }
select { min-height: 36px; border: 2px solid var(--linea-fuerte); border-radius: var(--radio-s); background: var(--superficie); font: inherit; color: var(--tinta-1); }
</style>
