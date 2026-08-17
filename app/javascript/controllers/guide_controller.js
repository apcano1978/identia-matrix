import { Controller } from "@hotwired/stimulus"

// El conmutador de la guía: un documento, dos lecturas.
//
//   recorrido    lectura continua — la prosa y las citas, sin casilla
//   validación   checklist ejecutable — la casilla, sin prosa
//
// Sin ida al servidor, porque el contenido ya está en la página: cambiar de
// modo no es pedir nada nuevo, es mirar lo mismo con otra cara. Lo que SÍ
// escribe es marcar un paso, y eso va por su formulario.
export default class extends Controller {
  static targets = ["mode", "walkthrough", "validation"]
  static classes = ["active"]

  select(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.mode)
  }

  show(mode) {
    this.modeTargets.forEach((tab) => {
      const on = tab.dataset.mode === mode
      tab.classList.toggle(...this.activeClasses, on)
      tab.classList.toggle("text-terminal-fg-3", !on)
    })

    this.walkthroughTargets.forEach((el) => el.classList.toggle("hidden", mode !== "walkthrough"))
    this.validationTargets.forEach((el) => el.classList.toggle("hidden", mode !== "validation"))
  }
}
