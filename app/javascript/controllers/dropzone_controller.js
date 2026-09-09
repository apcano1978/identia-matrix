import { Controller } from "@hotwired/stimulus"

// Arrastrar documentos sobre la caja para subirlos.
//
// ⚠ El input de fichero se queda PRESENTE Y UTILIZABLE debajo, no oculto. Dos
// razones, y las dos importan: sin JS la subida sigue funcionando —que es como
// funcionan las otras dos pantallas con Stimulus— y `attach_file` de Capybara
// no encuentra un input con `display:none`, así que ocultarlo dejaría la
// pantalla sin forma de probarse.
//
// Lo que este controlador añade es el arrastre; lo que hace que la pantalla
// exista es el input.
//
// ⚠ `autosubmit` (F12 · B5). En la ficha del proyecto la subida ES el
// formulario, así que soltar envía. En el alta de un evolutivo el mismo
// formulario lleva además el título y las casillas de ámbito: enviar al soltar
// mandaría el evolutivo a medio escribir. Ahí el arrastre solo rellena el input,
// y quien envía es el botón de abrir.
export default class extends Controller {
  static targets = ["input", "zone"]
  static classes = ["over"]
  static values = { autosubmit: { type: Boolean, default: true } }

  // `dragover` hay que interceptarlo aunque no haga nada visible: sin
  // `preventDefault` el navegador abre el fichero en la pestaña y se lleva la
  // página por delante.
  over(event) {
    event.preventDefault()
    this.zoneTarget.classList.add(...this.overClasses)
  }

  out(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove(...this.overClasses)
  }

  drop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove(...this.overClasses)

    const files = event.dataTransfer?.files
    if (!files || files.length === 0) return

    this.inputTarget.files = files
    // `change` no salta al asignar `files` por código, y hay quien escucha —la
    // línea de ámbito del alta cuenta los adjuntos—. Se dispara a mano.
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.submit()
  }

  // Elegir por el diálogo envía igual: un paso menos, y evita que alguien
  // seleccione ficheros y se quede mirando sin saber que falta pulsar.
  submit() {
    if (!this.autosubmitValue) return

    this.element.requestSubmit()
  }
}
