package dev.hotwire.nativeshell

import dev.hotwire.core.turbo.errors.VisitError
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

/**
 * Web destination for `hotwire://fragment/web`. Drops the launch splash once
 * the visit has something to show, including an error page.
 */
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class ShellWebFragment : HotwireWebFragment() {
    override fun onVisitRendered(location: String) {
        FirstVisitSplash.settle(activity)
    }

    override fun onVisitCompleted(location: String, completedOffline: Boolean) {
        FirstVisitSplash.settle(activity)
    }

    override fun onVisitErrorReceived(location: String, error: VisitError) {
        super.onVisitErrorReceived(location, error)
        FirstVisitSplash.settle(activity)
    }

    override fun onVisitErrorReceivedWithCachedSnapshotAvailable(location: String, error: VisitError) {
        FirstVisitSplash.settle(activity)
    }
}
