package dev.hotwire.nativeshell

import android.view.View
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import kotlin.math.max

/**
 * Android 16 ignores `windowOptOutEdgeToEdgeEnforcement`, so this shell always
 * lays out inside system bars. The root padding keeps the Hotwire toolbar,
 * the WebView, and the bottom tabs out of the status bar, navigation bar,
 * display cutout, and keyboard.
 *
 * Status-bar and navigation-bar insets are cleared before they reach children.
 * The toolbar's `fitsSystemWindows` padding and Hotwire's bottom-bar padding
 * would otherwise add the same inset again. IME insets are forwarded so the
 * bottom bar still hides while the keyboard is up.
 */
object ShellWindowInsets {
    data class Plan(
        val paddingLeft: Int,
        val paddingTop: Int,
        val paddingRight: Int,
        val paddingBottom: Int
    )

    fun plan(
        barLeft: Int,
        barTop: Int,
        barRight: Int,
        barBottom: Int,
        imeBottom: Int
    ): Plan {
        return Plan(
            paddingLeft = barLeft,
            paddingTop = barTop,
            paddingRight = barRight,
            paddingBottom = max(barBottom, imeBottom)
        )
    }

    fun apply(root: View) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            val plan = plan(
                barLeft = bars.left,
                barTop = bars.top,
                barRight = bars.right,
                barBottom = bars.bottom,
                imeBottom = ime.bottom
            )
            view.updatePadding(
                plan.paddingLeft,
                plan.paddingTop,
                plan.paddingRight,
                plan.paddingBottom
            )
            WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.statusBars(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.navigationBars(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.captionBar(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.displayCutout(), Insets.NONE)
                .setInsets(
                    WindowInsetsCompat.Type.ime(),
                    Insets.of(ime.left, ime.top, ime.right, ime.bottom)
                )
                .build()
        }
        ViewCompat.requestApplyInsets(root)
    }
}
