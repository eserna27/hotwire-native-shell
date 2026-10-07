import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Shell component "share". The native sheet reads `url`
// (ShareComponent MessageData). `title` is included when the page set one;
// this shell's decoder ignores it.
export default class extends BridgeComponent {
  static component = "share"

  connect() {
    super.connect()
    const url = this.bridgeElement.bridgeAttribute("url") || window.location.href
    const title = this.bridgeElement.bridgeAttribute("title")
    const data = { url }
    if (title) data.title = title
    this.send("connect", data)
  }
}
