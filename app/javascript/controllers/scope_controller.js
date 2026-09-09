import { Controller } from "@hotwired/stimulus"

// La línea que dice en qué estado está el ámbito documental de un evolutivo
// (F12 · B5).
//
// ⚠ NO ES DECORACIÓN, y por eso existe. Recortar el ámbito y no recortarlo son
// dos cosas distintas —una se sella con fecha y congela el conjunto; la otra
// sigue heredando lo que se suba mañana— y hasta B5 esa diferencia no se veía
// en ninguna parte. Es lo que pedía P25: que el paso de «todo» a «lo marcado»
// sea visible en el momento de darlo.
//
// Degrada solo: sin JS queda el texto que pintó el servidor, que es el estado
// inicial y es cierto —todo marcado, sin recortar—. Lo que se pierde es que
// cambie al desmarcar, no la verdad.
export default class extends Controller {
  static targets = ["box", "files", "state"]
  static values = { intact: String, trimmed: String }

  connect() {
    this.render()
  }

  render() {
    const total = this.boxTargets.length
    const marked = this.boxTargets.filter((box) => box.checked).length
    // Lo que sale marcado de fábrica: lo citable. Un documento sin cuerpo nace
    // desmarcado y desmarcarlo no puede contar como recortar — es la misma
    // regla que aplica `Initiatives::Open#scope_sources`, y si las dos no
    // dijeran lo mismo la pantalla mentiría.
    const byDefault = this.boxTargets.filter((box) => box.dataset.scopeDefault === "true").length

    this.stateTarget.textContent =
      marked === byDefault && this.untouched() ? this.intactValue
        : this.trimmedValue.replace("%{n}", marked).replace("%{total}", total)

    if (this.hasFilesTarget) this.stateTarget.textContent += this.attached()
  }

  // Marcado exactamente lo de fábrica, no «el mismo número». Dos cambios que se
  // compensan —desmarcar una citable y marcar una sin cuerpo— dejarían el
  // contador igual y el ámbito distinto.
  untouched() {
    return this.boxTargets.every((box) => box.checked === (box.dataset.scopeDefault === "true"))
  }

  attached() {
    const count = this.filesTarget.files?.length || 0
    if (count === 0) return ""

    return count === 1 ? " · 1 adjunta" : ` · ${count} adjuntas`
  }
}
