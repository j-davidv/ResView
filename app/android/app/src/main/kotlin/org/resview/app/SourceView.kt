package org.resview.app

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.webkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONTokener

internal fun sourceUrl(value: String): String? {
    val uri = Uri.parse(value)
    if (uri.scheme != "https" || uri.userInfo != null ||
        uri.port !in listOf(-1, 443) || uri.fragment != null) return null
    if (uri.host in listOf("www.prc.gov.ph", "prc.gov.ph")) {
        return if (uri.path.orEmpty().lowercase().endsWith(".pdf")) null else value
    }
    if (uri.host != "drive.google.com") return null
    val match = Regex("^/file/d/([A-Za-z0-9_-]{10,200})/(view|preview)/?$")
        .matchEntire(uri.path.orEmpty()) ?: return null
    return "https://drive.google.com/file/d/${match.groupValues[1]}/preview?hl=en"
}

class SourceViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView =
        SourceView(context, messenger, id, (args as? Map<*, *>)?.get("url") as? String ?: "")
}

private class SourceView(context: Context, messenger: BinaryMessenger, id: Int, initialUrl: String) :
    PlatformView, MethodChannel.MethodCallHandler {
    private val web = WebView(context)
    private val channel = MethodChannel(messenger, "org.resview/source_view/$id")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var revision = 0
    private var disposed = false
    private var failed = false
    private var currentUrl = ""

    init {
        WebView.setWebContentsDebuggingEnabled(
            context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0)
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            useWideViewPort = true
            @Suppress("DEPRECATION")
            saveFormData = false
        }
        if (Build.VERSION.SDK_INT >= 26) {
            web.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (!request.isForMainFrame) return false
                val target = sourceUrl(request.url.toString())
                if (target == null) {
                    event("blocked", request.url.toString())
                    return true
                }
                if (target != request.url.toString()) {
                    view.loadUrl(target)
                    return true
                }
                return false
            }

            override fun onPageStarted(view: WebView, url: String, icon: Bitmap?) {
                cancelSearch()
                if (sourceUrl(url) == null) {
                    view.stopLoading()
                    event("failed", currentUrl)
                    return
                }
                currentUrl = url
                failed = false
                event("loading", url)
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (!failed && url == currentUrl) {
                    if (Uri.parse(url).host == "drive.google.com") {
                        // Drive's mobile preview disables pinch zoom in its viewport.
                        view.evaluateJavascript("""
                            (() => {
                              const viewport = document.querySelector('meta[name="viewport"]');
                              if (viewport) viewport.content = 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes';
                            })()
                        """.trimIndent(), null)
                    }
                    event("loaded", url)
                }
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) failPage()
            }

            override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) {
                if (request.isForMainFrame && response.statusCode >= 400) failPage()
            }

            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                failPage()
                return true
            }
        }
        web.setDownloadListener { _, _, _, _, _ -> event("blocked", currentUrl) }
        channel.setMethodCallHandler(this)
        web.post {
            if (!disposed) {
                val target = sourceUrl(initialUrl)
                if (target == null) event("failed", initialUrl) else web.loadUrl(target)
            }
        }
    }

    private fun event(name: String, url: String) {
        if (!disposed) channel.invokeMethod(name, mapOf("url" to url))
    }

    private fun cancelSearch() {
        revision++
        handler.removeCallbacksAndMessages(null)
        pending?.error("SEARCH_CANCELLED", "Document changed", null)
        pending = null
    }

    private fun failPage() {
        failed = true
        cancelSearch()
        event("failed", currentUrl)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "back" -> {
                val back = web.canGoBack()
                if (back) web.goBack()
                result.success(back)
            }
            "find" -> {
                val query = call.argument<String>("query")?.trim().orEmpty()
                val direction = call.argument<Int>("direction") ?: 0
                if (failed || Uri.parse(currentUrl).host != "drive.google.com" ||
                    query.isEmpty() || query.length > 200 || direction !in -1..1) {
                    result.error("SEARCH_UNAVAILABLE", "Open a supported document before searching", null)
                    return
                }
                cancelSearch()
                pending = result
                openSearch(query, direction, revision, 0)
            }
            else -> result.notImplemented()
        }
    }

    private fun key(code: Int, meta: Int = 0) {
        web.dispatchKeyEvent(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, code, 0, meta))
        web.dispatchKeyEvent(KeyEvent(0, 0, KeyEvent.ACTION_UP, code, 0, 0))
    }

    private fun finishSearch(error: String? = null, value: Map<String, Int>? = null) {
        val result = pending ?: return
        pending = null
        (web.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
            .hideSoftInputFromWindow(web.windowToken, 0)
        if (error != null) result.error("SEARCH_UNAVAILABLE", error, null) else result.success(value)
    }

    private fun openSearch(query: String, direction: Int, token: Int, attempt: Int) {
        if (disposed || token != revision) return
        // shortcut: reviewed Drive DOM and input timing; re-review if its search UI changes.
        web.evaluateJavascript("""
            (() => {
              const doc = document.querySelector('[role="document"]');
              const input = [...document.querySelectorAll('input')].find(e =>
                /^(Find in document|Search in document|Hanapin sa dokumento)$/i.test(e.getAttribute('aria-label') || ''));
              if (!doc || !input) return false;
              doc.focus(); return true;
            })()
        """.trimIndent()) { ready ->
            if (disposed || token != revision) return@evaluateJavascript
            if (ready != "true") {
                if (attempt >= 24) finishSearch("The document search controls did not become available")
                else handler.postDelayed({ openSearch(query, direction, token, attempt + 1) }, 200)
                return@evaluateJavascript
            }
            web.requestFocus()
            key(KeyEvent.KEYCODE_F, KeyEvent.META_CTRL_ON)
            handler.postDelayed({ submitSearch(query, direction, token) }, 200)
        }
    }

    private fun submitSearch(query: String, direction: Int, token: Int) {
        if (disposed || token != revision) return
        web.evaluateJavascript("""
            (() => {
              const input = [...document.querySelectorAll('input')].find(e =>
                /^(Find in document|Search in document|Hanapin sa dokumento)$/i.test(e.getAttribute('aria-label') || ''));
              if (!input || input.getBoundingClientRect().right <= 0) return false;
              const bar = input.parentElement.parentElement.parentElement;
              bar.style.opacity = '0'; bar.style.pointerEvents = 'none';
              input.focus();
              if ($direction === 0) input.select();
              return true;
            })()
        """.trimIndent()) { ready ->
            if (disposed || token != revision) return@evaluateJavascript
            if (ready != "true") {
                finishSearch("The document search controls could not be opened")
                return@evaluateJavascript
            }
            handler.postDelayed({
                if (disposed || token != revision) return@postDelayed
                val connection = web.onCreateInputConnection(EditorInfo())
                if (connection == null) {
                    finishSearch("The document could not accept search text")
                    return@postDelayed
                }
                if (direction == 0) {
                    connection.commitText("", 1)
                    waitForInput("", token, 0) {
                        connection.commitText(query, 1)
                        waitForInput(query, token, 0) {
                            handler.postDelayed({ submitIfNeeded(connection, token) }, 300)
                        }
                    }
                } else {
                    val meta = if (direction < 0) KeyEvent.META_SHIFT_ON else 0
                    enter(connection, meta)
                    handler.postDelayed({ readSearch(token, 0) }, 200)
                }
            }, 100)
        }
    }

    private fun waitForInput(query: String, token: Int, attempt: Int, ready: () -> Unit) {
        if (disposed || token != revision) return
        web.evaluateJavascript("""
            (() => {
              const input = document.activeElement;
              const counter = input?.parentElement?.parentElement?.parentElement?.textContent || '';
              return input?.value === '' && counter !== '' ? null : input?.value;
            })()
        """.trimIndent()) { encoded ->
            if (disposed || token != revision) return@evaluateJavascript
            val entered = try { JSONTokener(encoded).nextValue() as? String } catch (_: Exception) { null }
            if (entered != query) {
                if (attempt >= 19) finishSearch("The document could not accept search text")
                else handler.postDelayed({ waitForInput(query, token, attempt + 1, ready) }, 100)
                return@evaluateJavascript
            }
            ready()
        }
    }

    private fun enter(connection: InputConnection, meta: Int = 0) {
        connection.sendKeyEvent(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER, 0, meta))
        connection.sendKeyEvent(KeyEvent(0, 0, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_ENTER, 0, 0))
    }

    private fun submitIfNeeded(connection: InputConnection, token: Int) {
        if (disposed || token != revision) return
        web.evaluateJavascript("document.activeElement?.parentElement?.parentElement?.parentElement?.textContent || ''") { encoded ->
            if (disposed || token != revision) return@evaluateJavascript
            val counter = try { JSONTokener(encoded).nextValue() as? String ?: "" } catch (_: Exception) { "" }
            if (counter.isBlank()) enter(connection)
            handler.postDelayed({ readSearch(token, 0) }, 200)
        }
    }

    private fun readSearch(token: Int, attempt: Int) {
        if (disposed || token != revision) return
        web.evaluateJavascript("""
            (() => {
              const input = [...document.querySelectorAll('input')].find(e =>
                /^(Find in document|Search in document|Hanapin sa dokumento)$/i.test(e.getAttribute('aria-label') || ''));
              return input?.parentElement.parentElement.parentElement.textContent || '';
            })()
        """.trimIndent()) { encoded ->
            if (disposed || token != revision) return@evaluateJavascript
            val text = try { JSONTokener(encoded).nextValue() as? String ?: "" } catch (_: Exception) { "" }
            val counts = Regex("\\d+").findAll(text).mapNotNull { it.value.toIntOrNull() }.toList()
            if (counts.size != 2 || counts[0] !in 0..counts[1]) {
                if (attempt >= 39) finishSearch("The document search did not return a result")
                else handler.postDelayed({ readSearch(token, attempt + 1) }, 200)
                return@evaluateJavascript
            }
            web.evaluateJavascript("document.querySelector('[role=\"document\"]')?.focus()", null)
            finishSearch(value = mapOf("current" to counts[0], "total" to counts[1]))
        }
    }

    override fun getView(): View = web

    override fun dispose() {
        cancelSearch()
        disposed = true
        channel.setMethodCallHandler(null)
        web.stopLoading()
        web.destroy()
    }
}
