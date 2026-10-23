# frozen_string_literal: true

module HotwireNativeShell
  # Markup for bridge controllers. Each helper emits nothing unless the
  # request is Hotwire Native, and nothing at all unless the page calls it.
  module NativeHelper
    def native_tabs
      return unless hotwire_native_app?

      tabs = HotwireNativeShell.config.bridge_tabs(signed_in: native_signed_in?, request: request)
      content_tag(:nav, safe_join(tabs.map { |tab| native_tab_link(tab) }), data: { controller: "bridge--tabs" })
    end

    # The ellipsis and the action sheet are one block in NATIVE_UI.md.
    # +native_menu+ emits that same block.
    def native_overflow_menu(items: nil, label: "Options", title: "Select an option")
      return unless hotwire_native_app?

      resolved = normalize_menu_items(items)
      return if resolved.empty?

      content_tag(:div, data: { controller: "menu bridge--menu" }) do
        safe_join([
          button_tag(label, type: "button", data: {
            controller: "bridge--overflow-menu",
            action: "click->bridge--menu#show click->menu#show",
            bridge_title: label
          }),
          tag.p(title, hidden: true, data: { bridge__menu_target: "title" }),
          *resolved.map { |item| native_menu_link(item) }
        ])
      end
    end

    def native_menu(items: nil, label: "Options", title: "Select an option")
      native_overflow_menu(items: items, label: label, title: title)
    end

    # +title+ is sent with the connect message. Android and iOS share sheets
    # in this shell read +url+ only and ignore +title+.
    def native_share(url:, title: nil)
      return unless hotwire_native_app?

      data = { controller: "bridge--share", bridge_url: url }
      data[:bridge_title] = title if title.present?
      tag.meta(data: data)
    end

    def native_notification_token(url: "/native/device_tokens")
      return unless hotwire_native_app?

      tag.div(hidden: true, data: { controller: "bridge--notification-token", bridge_url: url })
    end

    # Purchase and restore buttons for the subscription bridge. Product ids are
    # store subscription ids from the host app. Renders nothing in a browser,
    # and nothing when +product_id+ is blank. The buttons stay on the page:
    # they open the store sheet, they do not replace it.
    def native_subscription(product_id:, label: "Subscribe", restore_label: "Restore purchases", product_ids: nil, base_plan_id: nil, offer_token: nil, account_token: nil, restore: true, status: true)
      return unless hotwire_native_app?

      primary = product_id.to_s.strip
      return if primary.empty?

      ids = Array(product_ids).map { |id| id.to_s.strip }.reject(&:empty?)
      data = {
        controller: "bridge--subscription",
        bridge_product_id: primary,
        bridge_status: status ? "true" : "false"
      }
      data[:bridge_product_ids] = ids.join(" ") if ids.any?
      data[:bridge_base_plan_id] = base_plan_id.to_s if base_plan_id.present?
      data[:bridge_offer_token] = offer_token.to_s if offer_token.present?
      data[:bridge_account_token] = account_token.to_s if account_token.present?

      content_tag(:div, data: data) do
        buttons = [ button_tag(label, type: "button", data: { action: "bridge--subscription#purchase" }) ]
        if restore
          buttons << button_tag(restore_label, type: "button", data: { action: "bridge--subscription#restore" })
        end
        safe_join(buttons)
      end
    end

    def native_haptic(feedback: "success", label: "Tap", **attributes, &block)
      return unless hotwire_native_app?

      data = (attributes.delete(:data) || {}).merge(
        controller: "bridge--haptic",
        action: "bridge--haptic#vibrate",
        bridge_feedback: feedback
      )
      button_tag(label, type: "button", data: data, **attributes, &block)
    end

    # Guideline 5.1.1(v). Renders nothing until +account_deletion_path+ is set,
    # and nothing in a normal browser.
    def native_account_deletion_link(label = "Delete account")
      path = HotwireNativeShell.config.account_deletion_path
      return if path.blank? || !hotwire_native_app?

      link_to(label, path)
    end

    private

    def native_tab_link(tab)
      data = {
        bridge__tabs_target: "tab",
        bridge_id: tab[:id],
        bridge_title: tab[:title],
        bridge_icon: tab[:icon] || "home",
        bridge_path: tab[:path],
        bridge_url: tab[:url],
        bridge_sf_symbol: tab[:sf_symbol],
        bridge_android_icon: tab[:android_icon]
      }
      data[:bridge_active] = "true" if tab[:active]
      tag.a(tab[:title], href: tab[:href] || tab[:path], data: data.compact)
    end

    def native_menu_link(item)
      data = { bridge__menu_target: "item", bridge_title: item[:title] }
      data[:turbo_method] = item[:method] if item[:method]
      tag.a(item[:title], href: item[:href], data: data)
    end

    def normalize_menu_items(items)
      source = items.nil? ? HotwireNativeShell.config.menu_items_for(native_signed_in?) : items
      Array(source).filter_map do |item|
        hash = item.is_a?(MenuItem) ? item.as_hash : item.symbolize_keys
        title = hash[:title].to_s
        href = (hash[:href] || hash[:path]).to_s
        next if title.empty? || href.empty?

        entry = { title: title, href: href }
        entry[:method] = hash[:method].to_s.downcase if hash[:method].present? && hash[:method].to_s.downcase != "get"
        entry
      end
    end
  end
end
