import { BridgeComponent, BridgeElement } from "@hotwired/hotwire-native-bridge"

// Shell component "tabs". Script from docs/BRIDGES.md.
export default class extends BridgeComponent {
  static component = "tabs"
  static targets = ["tab"]

  connect() {
    super.connect()
    const tabs = this.tabTargets.flatMap((element) => {
      const bridgeElement = new BridgeElement(element)
      if (bridgeElement.disabled) return []
      let path = bridgeElement.bridgeAttribute("path") || ""
      if (!path && element.getAttribute("href")) {
        try {
          path = new URL(element.href, window.location.href).pathname
        } catch (e) {
          path = ""
        }
      }
      return [{
        id: bridgeElement.bridgeAttribute("id"),
        title: bridgeElement.title,
        icon: bridgeElement.bridgeAttribute("icon") || "home",
        sf_symbol: bridgeElement.bridgeAttribute("sf-symbol") || "",
        android_icon: bridgeElement.bridgeAttribute("android-icon") || "",
        path,
        url: bridgeElement.bridgeAttribute("url") || "",
        active: bridgeElement.bridgeAttribute("active") === "true"
      }]
    })
    this.send("connect", { tabs })
  }
}
