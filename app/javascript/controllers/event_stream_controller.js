import { Controller } from "@hotwired/stimulus"

// El log se rellena por arriba: lo nuevo llega con `prepend`, así que "seguir el
// log" es quedarse arriba del todo.
//
// Y se PAUSA al pasar el ratón. Un log que salta mientras lo lees es
// inservible: cuando alguien baja a mirar una línea de hace diez minutos, lo
// último que quiere es que la siguiente transición se lo devuelva al principio.
export default class extends Controller {
  static targets = ["log"]
  static values = { max: { type: Number, default: 40 } }

  connect() {
    this.paused = false
    this.observer = new MutationObserver(() => this.onNewEvent())
    this.observer.observe(this.logTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  pause() { this.paused = true }

  resume() {
    this.paused = false
    this.follow()
  }

  onNewEvent() {
    this.trim()
    this.follow()
  }

  follow() {
    if (this.paused) return
    this.logTarget.scrollTop = 0
  }

  // Sin esto el panel crece sin techo en una sesión larga y el navegador acaba
  // guardando miles de nodos que nadie va a mirar.
  trim() {
    const extra = this.logTarget.children.length - this.maxValue
    for (let i = 0; i < extra; i++) this.logTarget.lastElementChild?.remove()
  }
}
