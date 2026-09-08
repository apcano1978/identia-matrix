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
export default class extends Controller {
  static targets = ["input", "zone"]
  static classes = ["over"]

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
    this.submit()
  }

  // Elegir por el diálogo envía igual: un paso menos, y evita que alguien
  // seleccione ficheros y se quede mirando sin saber que falta pulsar.
  submit() {
    this.element.requestSubmit()
  }
}
