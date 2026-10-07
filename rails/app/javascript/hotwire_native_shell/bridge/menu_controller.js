import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

// Shell component "menu". Script from docs/BRIDGES.md.
export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["title", "item"]

  show(event) {
    if (!this.enabled) return
    event.stopImmediatePropagation()
    const title = new BridgeElement(this.titleTarget).title
    const items = this.itemTargets.flatMap((element, index) => {
      const bridgeElement = new BridgeElement(element)
      if (bridgeElement.disabled) return []
      return [{ title: bridgeElement.title, index }]
    })
    const rect = event.target.getBoundingClientRect()
    this.send("display", {
      title,
      items,
      source: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    }, (message) => {
      new BridgeElement(this.itemTargets[message.data.selectedIndex]).click()
    })
  }
}
