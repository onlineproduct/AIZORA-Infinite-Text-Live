from pathlib import Path
import re

root = Path("android")
settings = next((p for p in [root / "settings.gradle.kts", root / "settings.gradle"] if p.exists()), None)
app_gradle = next((p for p in [root / "app/build.gradle.kts", root / "app/build.gradle"] if p.exists()), None)
manifest = root / "app/src/main/AndroidManifest.xml"
if not settings or not app_gradle or not manifest.exists():
    raise SystemExit("Generated Android Gradle files or manifest are missing")

# Add JitPack to dependency resolution. Recent Flutter templates may omit
# dependencyResolutionManagement entirely, so create it when absent.
s = settings.read_text()
jitpack = 'maven { url = uri("https://jitpack.io") }' if settings.suffix == ".kts" else "maven { url 'https://jitpack.io' }"
if "jitpack.io" not in s:
    if "dependencyResolutionManagement" not in s:
        block = (
            '\ndependencyResolutionManagement {\n'
            '    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)\n'
            '    repositories {\n'
            '        google()\n'
            '        mavenCentral()\n'
            '        ' + jitpack + '\n'
            '    }\n'
            '}\n'
        )
        s += block
    else:
        # Insert into the repositories block nested under dependencyResolutionManagement.
        marker = "dependencyResolutionManagement"
        pos = s.find(marker)
        repo_pos = s.find("repositories", pos)
        open_pos = s.find("{", repo_pos)
        if repo_pos < 0 or open_pos < 0:
            raise SystemExit("Could not locate dependencyResolutionManagement.repositories")
        depth = 1
        close_pos = open_pos + 1
        while close_pos < len(s) and depth:
            if s[close_pos] == "{":
                depth += 1
            elif s[close_pos] == "}":
                depth -= 1
            close_pos += 1
        if depth:
            raise SystemExit("Unbalanced dependencyResolutionManagement.repositories block")
        s = s[:close_pos - 1] + "\n        " + jitpack + "\n    " + s[close_pos - 1:]
    settings.write_text(s)

g = app_gradle.read_text()
dep = 'implementation("com.github.pedroSG94.RootEncoder:library:2.6.2")' if app_gradle.suffix == ".kts" else "implementation 'com.github.pedroSG94.RootEncoder:library:2.6.2'"
if "RootEncoder:library" not in g:
    if re.search(r"(?m)^\s*dependencies\s*\{", g):
        g = re.sub(r"(?m)^(\s*dependencies\s*\{)", lambda m: m.group(1) + "\n    " + dep, g, count=1)
    else:
        g += "\n\ndependencies {\n    " + dep + "\n}\n"
    if "RootEncoder:library" not in g:
        raise SystemExit("Could not insert RootEncoder dependency")
    app_gradle.write_text(g)

m = manifest.read_text()
if "android.permission.INTERNET" not in m:
    m = m.replace("<manifest", '<manifest')
    m = re.sub(r"(<application)", '    <uses-permission android:name="android.permission.INTERNET" />\n    \\1', m, count=1)
    manifest.write_text(m)

pkg = "com.aizora.aizora_infinite_text_live"
kotlin_dir = root / "app/src/main/kotlin" / Path(*pkg.split("."))
kotlin_dir.mkdir(parents=True, exist_ok=True)
main = kotlin_dir / "MainActivity.kt"
main.write_text(r'''package com.aizora.aizora_infinite_text_live

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.InternalAudioSource
import com.pedro.encoder.input.sources.audio.NoAudioSource
import com.pedro.encoder.input.sources.video.NoVideoSource
import com.pedro.encoder.input.sources.video.ScreenSource
import com.pedro.library.generic.GenericStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), ConnectChecker {
  private val channelName = "aizora.live"
  private val projectionRequest = 7401
  private var pendingStart: MethodChannel.Result? = null
  private var stream: GenericStream? = null
  private var projection: MediaProjection? = null
  private var endpoint: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startLive" -> {
            if (pendingStart != null || stream?.isStreaming == true) {
              result.error("ALREADY_RUNNING", "A live session is already starting or running.", null)
              return@setMethodCallHandler
            }
            val server = call.argument<String>("serverUrl")?.trim().orEmpty().trimEnd('/')
            val key = call.argument<String>("streamKey")?.trim().orEmpty()
            if (!(server.startsWith("rtmp://") || server.startsWith("rtmps://")) || key.isBlank()) {
              result.error("INVALID_INPUT", "A valid RTMP(S) server and stream key are required.", null)
              return@setMethodCallHandler
            }
            endpoint = "$server/$key"
            pendingStart = result
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            @Suppress("DEPRECATION")
            startActivityForResult(manager.createScreenCaptureIntent(), projectionRequest)
          }
          "stopLive" -> {
            stopPublisher()
            result.success("Stop requested")
          }
          "status" -> result.success(if (stream?.isStreaming == true) "streaming" else "stopped")
          else -> result.notImplemented()
        }
      }
  }

  @Deprecated("Deprecated by Android, retained for Flutter Activity compatibility")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode != projectionRequest) return
    val callback = pendingStart ?: return
    if (resultCode != Activity.RESULT_OK || data == null) {
      pendingStart = null
      endpoint = null
      callback.error("CAPTURE_DENIED", "Screen capture permission was not granted.", null)
      return
    }
    try {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
        throw IllegalStateException("Internal app audio capture requires Android 10 or newer.")
      }
      val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
      projection = manager.getMediaProjection(resultCode, data)
        ?: throw IllegalStateException("Android did not provide a screen capture session.")
      val publisher = GenericStream(this, this, NoVideoSource(), NoAudioSource())
      publisher.getGlInterface().setForceRender(true, 15)
      if (!publisher.prepareVideo(720, 1280, 1_800_000) ||
          !publisher.prepareAudio(44_100, true, 128_000)) {
        publisher.release()
        throw IllegalStateException("The device could not prepare H.264/AAC encoders.")
      }
      publisher.changeVideoSource(ScreenSource(applicationContext, projection!!))
      publisher.changeAudioSource(InternalAudioSource(projection!!))
      stream = publisher
      publisher.startStream(endpoint!!)
      // The result is completed only by the encoder's connection callback.
    } catch (error: Exception) {
      pendingStart = null
      endpoint = null
      stopPublisher()
      callback.error("PUBLISHER_START_FAILED", error.message ?: "Could not start publisher.", null)
    }
  }

  private fun stopPublisher() {
    pendingStart?.let {
      it.error("CANCELLED", "Live start was cancelled.", null)
    }
    pendingStart = null
    try { stream?.stopStream() } catch (_: Exception) {}
    try { stream?.release() } catch (_: Exception) {}
    stream = null
    try { projection?.stop() } catch (_: Exception) {}
    projection = null
    endpoint = null
  }

  override fun onConnectionStarted(url: String) {}
  override fun onConnectionSuccess() {
    runOnUiThread {
      pendingStart?.success("Connected to streaming server; verify the live preview on Facebook.")
      pendingStart = null
    }
  }
  override fun onNewBitrate(bitrate: Long) {}
  override fun onConnectionFailed(reason: String) {
    runOnUiThread {
      pendingStart?.error("RTMP_CONNECTION_FAILED", reason, null)
      pendingStart = null
      stopPublisher()
    }
  }
  override fun onDisconnect() {}
  override fun onAuthError() {
    runOnUiThread {
      pendingStart?.error("RTMP_AUTH_ERROR", "The streaming server rejected the stream key.", null)
      pendingStart = null
      stopPublisher()
    }
  }
  override fun onAuthSuccess() {}
  override fun onDestroy() {
    stopPublisher()
    super.onDestroy()
  }
}
''')
print("Generated RootEncoder Android publisher source and configured dependency/permissions.")
