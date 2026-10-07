import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Shell component "overflow-menu". Script from docs/BRIDGES.md.
export default class extends BridgeComponent {
  static component = "overflow-menu"

  connect() {
    super.connect()
    this.send("connect", { label: this.bridgeElement.title }, () => {
      this.bridgeElement.click()
    })
  }
}
