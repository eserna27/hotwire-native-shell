import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Shell component "subscription".
// purchase, restore, and status send the product ids on this element.
// The native reply is dispatched as hotwire-native-shell:subscription.
// After the server verifies a transaction, dispatch
// hotwire-native-shell:subscription-finish with that transaction so the
// shell can finish it (StoreKit) or acknowledge it (Play Billing).
export default class extends BridgeComponent {
  static component = "subscription"

  connect() {
    super.connect()
    this.finishRequest = (event) => this.finishTransactions(event)
    this.element.addEventListener("hotwire-native-shell:subscription-finish", this.finishRequest)
    if (this.bridgeElement.bridgeAttribute("status") !== "false") this.status()
  }

  disconnect() {
    this.element.removeEventListener("hotwire-native-shell:subscription-finish", this.finishRequest)
    super.disconnect()
  }

  purchase(event) {
    if (event) event.preventDefault()
    this.send("purchase", this.payload(), (message) => this.publish("purchase", message))
  }

  restore(event) {
    if (event) event.preventDefault()
    this.send("restore", this.payload(), (message) => this.publish("restore", message))
  }

  status(event) {
    if (event) event.preventDefault()
    this.send("status", this.payload(), (message) => this.publish("status", message))
  }

  finishTransactions(event) {
    const detail = (event && event.detail) || {}
    const transactions = detail.transactions || [detail]
    transactions.forEach((transaction) => {
      if (!transaction) return
      const data = this.payload()
      if (transaction.product_id) data.product_id = transaction.product_id
      if (transaction.transaction_id) data.transaction_id = transaction.transaction_id
      if (transaction.purchase_token) data.purchase_token = transaction.purchase_token
      this.send("finish", data, (message) => this.publish("finish", message))
    })
  }

  payload() {
    const productId = this.bridgeElement.bridgeAttribute("product-id") || ""
    const listed = (this.bridgeElement.bridgeAttribute("product-ids") || "")
      .split(/[\s,]+/)
      .filter(Boolean)
    const productIds = listed.slice()
    if (productId && productIds.indexOf(productId) === -1) productIds.unshift(productId)
    const data = { product_id: productId, product_ids: productIds }
    const basePlanId = this.bridgeElement.bridgeAttribute("base-plan-id")
    const offerToken = this.bridgeElement.bridgeAttribute("offer-token")
    const accountToken = this.bridgeElement.bridgeAttribute("account-token")
    if (basePlanId) data.base_plan_id = basePlanId
    if (offerToken) data.offer_token = offerToken
    if (accountToken) data.account_token = accountToken
    return data
  }

  publish(eventName, message) {
    const data = (message && message.data) || {}
    this.element.dispatchEvent(new CustomEvent("hotwire-native-shell:subscription", {
      bubbles: true,
      detail: Object.assign({ event: eventName }, data)
    }))
  }
}
