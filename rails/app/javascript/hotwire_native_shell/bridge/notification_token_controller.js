import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Shell component "notification-token".
// The shell replies to "get" with { token, provider }.
// "placeholder" / "placeholder-not-a-device-token" is not stored.
// A real token is posted as { token, provider, platform }.
const PLACEHOLDER_TOKEN = "placeholder-not-a-device-token"

export default class extends BridgeComponent {
  static component = "notification-token"

  connect() {
    super.connect()
    this.get()
  }

  get() {
    this.send("get", {}, (message) => {
      const data = (message && message.data) || {}
      if (!data.token || data.provider === "placeholder" || data.token === PLACEHOLDER_TOKEN) return
      this.register(data.token, data.provider)
    })
  }

  register(token, provider) {
    const csrf = document.querySelector("meta[name='csrf-token']")
    const platform = document.documentElement.dataset.bridgePlatform || ""
    const url = this.bridgeElement.bridgeAttribute("url") || "/native/device_tokens"
    window.fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrf ? csrf.content : ""
      },
      body: JSON.stringify({ token, provider, platform })
    })
  }
}
