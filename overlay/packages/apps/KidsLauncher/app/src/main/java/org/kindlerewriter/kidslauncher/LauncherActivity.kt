package org.kindlerewriter.kidslauncher

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.GridLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Minimal launcher for KindleRewriter reading tablets.
 * Shows a simple grid of allowed apps: reader, browser, file manager.
 * No app drawer, no widgets, no distractions.
 */
class LauncherActivity : Activity() {

    private data class AppEntry(
        val label: String,
        val iconRes: Int,
        val packageName: String,
        val activityName: String? = null
    )

    private val allowedApps = listOf(
        AppEntry(
            label = "Read Books",
            iconRes = R.drawable.ic_books,
            packageName = "org.koreader.launcher"
        ),
        AppEntry(
            label = "Browse Web",
            iconRes = R.drawable.ic_browser,
            packageName = "org.nicoco.nicobrowser",
            activityName = null // fall back to launch intent
        ),
        AppEntry(
            label = "My Files",
            iconRes = R.drawable.ic_files,
            packageName = "com.android.documentsui"
        )
    )

    // Fallback browsers to try if the primary isn't installed
    private val fallbackBrowsers = listOf(
        "org.nicoco.nicobrowser",
        "org.lineageos.jelly",
        "com.android.browser",
        "org.mozilla.firefox",
        "com.opera.mini.native"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Full-screen immersive
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_FULLSCREEN
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = Color.TRANSPARENT

        val root = buildLauncherView()
        setContentView(root)
    }

    override fun onBackPressed() {
        // Do nothing: this IS the home screen
    }

    private fun buildLauncherView(): View {
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#1a1a2e"))
            isFillViewport = true
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(48), dp(32), dp(48))
        }

        // Header
        val header = TextView(this).apply {
            text = "What would you like to do?"
            setTextColor(Color.parseColor("#e0e0e0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(40))
        }
        container.addView(header)

        // App grid
        val grid = GridLayout(this).apply {
            columnCount = if (resources.configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE) 3 else 1
            rowCount = if (columnCount == 3) 1 else allowedApps.size
            useDefaultMargins = true
        }

        for (app in allowedApps) {
            val card = buildAppCard(app)
            val params = GridLayout.LayoutParams().apply {
                width = 0
                height = GridLayout.LayoutParams.WRAP_CONTENT
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins(dp(8), dp(8), dp(8), dp(8))
            }
            grid.addView(card, params)
        }

        container.addView(grid)
        scrollView.addView(container)
        return scrollView
    }

    private fun buildAppCard(app: AppEntry): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(32), dp(24), dp(32))
            setBackgroundColor(Color.parseColor("#16213e"))
            isClickable = true
            isFocusable = true

            setOnClickListener { launchApp(app) }
        }

        val icon = ImageView(this).apply {
            setImageResource(app.iconRes)
            val size = dp(72)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER
                bottomMargin = dp(12)
            }
            setColorFilter(Color.parseColor("#e94560"))
        }
        card.addView(icon)

        val label = TextView(this).apply {
            text = app.label
            setTextColor(Color.parseColor("#e0e0e0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
        }
        card.addView(label)

        return card
    }

    private fun launchApp(app: AppEntry) {
        // Special handling for browser: try fallbacks
        if (app.label == "Browse Web") {
            launchBrowser()
            return
        }

        val intent = if (app.activityName != null) {
            Intent().apply {
                component = ComponentName(app.packageName, app.activityName)
            }
        } else {
            packageManager.getLaunchIntentForPackage(app.packageName)
        }

        if (intent != null) {
            try {
                startActivity(intent)
            } catch (e: Exception) {
                showToast("Could not open ${app.label}")
            }
        } else {
            showToast("${app.label} is not installed")
        }
    }

    private fun launchBrowser() {
        for (pkg in fallbackBrowsers) {
            val intent = packageManager.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                try {
                    startActivity(intent)
                    return
                } catch (_: Exception) {
                    continue
                }
            }
        }

        // Last resort: open a URL with whatever handles it
        try {
            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.gutenberg.org"))
            startActivity(intent)
        } catch (_: Exception) {
            showToast("No browser found")
        }
    }

    private fun showToast(message: String) {
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
