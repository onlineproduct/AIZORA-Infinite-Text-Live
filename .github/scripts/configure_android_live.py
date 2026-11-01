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
            '    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)\n'
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

# Flutter's generated root build.gradle(.kts) declares project repositories.
# Add JitPack via an allprojects block; the settings script uses PREFER_PROJECT.
root_gradle = next((p for p in [root / "build.gradle.kts", root / "build.gradle"] if p.exists()), None)
if not root_gradle:
    raise SystemExit("Root Android Gradle file is missing")
rg = root_gradle.read_text()
if "jitpack.io" not in rg:
    if root_gradle.suffix == ".kts":
        rg += '\n\nallprojects {\n    repositories {\n        maven { url = uri("https://jitpack.io") }\n    }\n}\n'
    else:
        rg += "\n\nallprojects {\n    repositories {\n        maven { url 'https://jitpack.io' }\n    }\n}\n"
    root_gradle.write_text(rg)

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

# Declare the Android 14 MediaProjection foreground-service permissions and service.
if "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" not in m:
    m = m.replace("<manifest", '<manifest', 1)
    m = m.replace("<application", '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />\\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />\\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\\n    <application', 1)
service_decl = '        <service android:name=".LivePublisherService" android:exported="false" android:foregroundServiceType="mediaProjection" />'
if "LivePublisherService" not in m:
    m = m.replace("</application>", service_decl + "\\n    </application>")
manifest.write_text(m)

if "android.permission.INTERNET" not in m:
    m = m.replace("<manifest", '<manifest')
    m = re.sub(r"(<application)", '    <uses-permission android:name="android.permission.INTERNET" />\n    \\1', m, count=1)
    manifest.write_text(m)

service = kotlin_dir / "LivePublisherService.kt"
service.write_text(r'''package com.aizora.aizora_infinite_text_live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.sources.audio.InternalAudioSource
import com.pedro.encoder.input.sources.video.NoVideoSource
import com.pedro.encoder.input.sources.video.ScreenSource
import com.pedro.library.generic.GenericStream

class LivePublisherService : Service(), ConnectChecker {
  companion object {
    const val ACTION_CONNECTED = "com.aizora.live.CONNECTED"
    const val ACTION_ERROR = "com.aizora.live.ERROR"
    const val EXTRA_RESULT_CODE = "projection_result_code"
    const val EXTRA_PROJECTION_DATA = "projection_data"
    const val EXTRA_ENDPOINT = "endpoint"
    private const val CHANNEL_ID = "aizora_live_publisher"
    private const val NOTIFICATION_ID = 7402
  }

  private var projection: MediaProjection? = null
  private var publisher: GenericStream? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    try {
      val notification = createNotification()
      if (Build.VERSION.SDK_INT >= 29) {
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
      } else {
        startForeground(NOTIFICATION_ID, notification)
      }
      val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
      @Suppress("DEPRECATION")
      val data = if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_PROJECTION_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_PROJECTION_DATA)
      val endpoint = intent?.getStringExtra(EXTRA_ENDPOINT).orEmpty()
      if (resultCode == 0 || data == null || endpoint.isBlank()) {
        throw IllegalArgumentException("Screen permission or RTMP endpoint is missing.")
      }
      val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
      projection = manager.getMediaProjection(resultCode, data)
        ?: throw IllegalStateException("Android did not provide a screen capture session.")
      val stream = GenericStream(this, this, NoVideoSource(), com.pedro.encoder.input.sources.audio.NoAudioSource())
      stream.getGlInterface().setForceRender(true, 15)
      if (!stream.prepareVideo(720, 1280, 1_800_000) || !stream.prepareAudio(44_100, true, 128_000)) {
        stream.release()
        throw IllegalStateException("The device could not prepare H.264/AAC encoders.")
      }
      stream.changeVideoSource(ScreenSource(applicationContext, projection!!))
      stream.changeAudioSource(InternalAudioSource(projection!!))
      publisher = stream
      stream.startStream(endpoint)
    } catch (error: Exception) {
      sendBroadcast(Intent(ACTION_ERROR).setPackage(packageName).putExtra("message", error.message ?: "Publisher startup failed."))
      stopSelf()
    }
    return START_NOT_STICKY
  }

  private fun createNotification(): Notification {
    val manager = getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= 26) {
      manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "AIZORA Live", NotificationManager.IMPORTANCE_LOW))
    }
    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
    return builder.setContentTitle("AIZORA Live is running")
      .setContentText("Screen streaming is active. Tap Stop Live in AIZORA to end it.")
      .setSmallIcon(android.R.drawable.presence_video_online)
      .setOngoing(true)
      .build()
  }

  override fun onConnectionStarted(url: String) {}
  override fun onConnectionSuccess() {
    sendBroadcast(Intent(ACTION_CONNECTED).setPackage(packageName))
  }
  override fun onNewBitrate(bitrate: Long) {}
  override fun onConnectionFailed(reason: String) {
    sendBroadcast(Intent(ACTION_ERROR).setPackage(packageName).putExtra("message", reason))
    stopSelf()
  }
  override fun onDisconnect() {}
  override fun onAuthError() {
    sendBroadcast(Intent(ACTION_ERROR).setPackage(packageName).putExtra("message", "Streaming server rejected the stream key."))
    stopSelf()
  }
  override fun onAuthSuccess() {}
  override fun onDestroy() {
    try { publisher?.stopStream() } catch (_: Exception) {}
    try { publisher?.release() } catch (_: Exception) {}
    publisher = null
    try { projection?.stop() } catch (_: Exception) {}
    projection = null
    super.onDestroy()
  }
}
''')

pkg = "com.aizora.aizora_infinite_text_live"
kotlin_dir = root / "app/src/main/kotlin" / Path(*pkg.split("."))
kotlin_dir.mkdir(parents=True, exist_ok=True)
main = kotlin_dir / "MainActivity.kt"
main.write_text(r'''package com.aizora.aizora_infinite_text_live

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.projection.MediaProjectionManager
import android.os.Build
import com.aizora.aizora_infinite_text_live.LivePublisherService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "aizora.live"
  private val projectionRequest = 7401
  private var pendingStart: MethodChannel.Result? = null
  private var receiverRegistered = false
  private val liveReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        LivePublisherService.ACTION_CONNECTED -> {
          pendingStart?.success("Connected to streaming server; verify the live preview on Facebook.")
          pendingStart = null
        }
        LivePublisherService.ACTION_ERROR -> {
          pendingStart?.error("PUBLISHER_ERROR", intent.getStringExtra("message") ?: "Publisher failed.", null)
          pendingStart = null
        }
      }
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val filter = IntentFilter().apply {
      addAction(LivePublisherService.ACTION_CONNECTED)
      addAction(LivePublisherService.ACTION_ERROR)
    }
    if (Build.VERSION.SDK_INT >= 33) {
      registerReceiver(liveReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      @Suppress("DEPRECATION")
      registerReceiver(liveReceiver, filter)
    }
    receiverRegistered = true

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startLive" -> {
            if (pendingStart != null) {
              result.error("ALREADY_RUNNING", "A live session is already starting.", null)
              return@setMethodCallHandler
            }
            val server = call.argument<String>("serverUrl")?.trim().orEmpty().trimEnd('/')
            val key = call.argument<String>("streamKey")?.trim().orEmpty()
            if (!(server.startsWith("rtmp://") || server.startsWith("rtmps://")) || key.isBlank()) {
              result.error("INVALID_INPUT", "A valid RTMP(S) server and stream key are required.", null)
              return@setMethodCallHandler
            }
            pendingStart = result
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            @Suppress("DEPRECATION")
            startActivityForResult(manager.createScreenCaptureIntent(), projectionRequest)
          }
          "stopLive" -> {
            stopService(Intent(this, LivePublisherService::class.java))
            pendingStart?.error("CANCELLED", "Live start was cancelled.", null)
            pendingStart = null
            result.success("Stop requested")
          }
          "status" -> result.success("Use Facebook Live Producer to verify the stream.")
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
      callback.error("CAPTURE_DENIED", "Screen capture permission was not granted.", null)
      return
    }
    try {
      val server = intent.getStringExtra("unused") // Do not reuse Activity intent for credentials.
      val callData = liveStartData
      if (callData == null) throw IllegalStateException("Live server details were lost.")
      val serviceIntent = Intent(this, LivePublisherService::class.java).apply {
        putExtra(LivePublisherService.EXTRA_RESULT_CODE, resultCode)
        putExtra(LivePublisherService.EXTRA_PROJECTION_DATA, data)
        putExtra(LivePublisherService.EXTRA_ENDPOINT, callData)
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(serviceIntent) else startService(serviceIntent)
      liveStartData = null
    } catch (error: Exception) {
      pendingStart = null
      callback.error("PUBLISHER_START_FAILED", error.message ?: "Could not start foreground publisher.", null)
    }
  }

  private var liveStartData: String? = null

  override fun onDestroy() {
    if (receiverRegistered) {
      try { unregisterReceiver(liveReceiver) } catch (_: Exception) {}
    }
    super.onDestroy()
  }

  // Store the endpoint only for the duration of the user-approved start flow.
  private fun rememberEndpoint(endpoint: String) { liveStartData = endpoint }
}
'''))
print("Generated RootEncoder Android publisher source and configured dependency/permissions.")
