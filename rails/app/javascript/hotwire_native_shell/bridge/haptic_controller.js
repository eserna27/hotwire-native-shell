import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Shell component "haptic". Script from docs/BRIDGES.md.
export default class extends BridgeComponent {
  static component = "haptic"

  vibrate() {
    const feedback = this.bridgeElement.bridgeAttribute("feedback") || "success"
    this.send("vibrate", { feedback })
  }
}
