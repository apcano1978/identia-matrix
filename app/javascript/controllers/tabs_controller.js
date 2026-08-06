import { Controller } from "@hotwired/stimulus"

// Pestañas de panel. Sin navegación: cambiar de META a LOG no debería recargar
// nada ni ensuciar el historial del navegador — es mirar lo mismo de otra forma.
export default class extends Controller {
  static targets = ["tab", "pane"]

  select(event) {
    const chosen = event.currentTarget.dataset.tab

    this.tabTargets.forEach((tab) => {
      const on = tab.dataset.tab === chosen
      tab.classList.toggle("text-antique-gold", on)
      tab.classList.toggle("border-b", on)
      tab.classList.toggle("border-antique-gold", on)
      tab.classList.toggle("text-terminal-fg-3", !on)
    })

    this.paneTargets.forEach((pane) => {
      pane.classList.toggle("hidden", pane.dataset.pane !== chosen)
    })
  }
}
