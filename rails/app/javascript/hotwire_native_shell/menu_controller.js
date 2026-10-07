import { Controller } from "@hotwired/stimulus"

// Web fallback for the overflow button. bridge--menu#show stops this click
// when the native menu component is enabled.
export default class extends Controller {
  show(event) {
    event.preventDefault()
    this.element.querySelectorAll("[data-bridge--menu-target='item']").forEach((item) => {
      item.hidden = false
    })
  }
}
