package com.cyrene.music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.media.session.MediaButtonReceiver
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.MediaBrowserCompat
import android.content.pm.ServiceInfo

/**
 * 自定义 Android 媒体通知前台服务
 *
 * - 继续复用 audio_service 提供的 MediaBrowserService + MediaSession
 * - 仅接管通知 UI（MediaStyle Notification），以便更好适配国产 ROM 的“上岛”策略
 */
class CustomMediaNotificationService : Service() {

    companion object {
        private const val TAG = "CustomMediaNotification"
        private const val NOTIFICATION_ID = 20250101
        private const val CHANNEL_ID = "cyrene_music_media_custom"
        private const val CHANNEL_NAME = "Cyrene Music 媒体播放"
        private const val ACTION_TOGGLE_LYRIC = "com.cyrene.music.action.TOGGLE_LYRIC"

        fun start(context: Context) {
            val intent = Intent(context, CustomMediaNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CustomMediaNotificationService::class.java)
            context.stopService(intent)
        }
    }

    private var mediaBrowser: MediaBrowserCompat? = null
    private var mediaController: MediaControllerCompat? = null
    private var currentMetadata: MediaMetadataCompat? = null
    private var currentState: PlaybackStateCompat? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        createNotificationChannel()

        // 通过 MediaBrowser 连接到 audio_service 的 MediaBrowserService
        mediaBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, com.ryanheise.audioservice.AudioService::class.java),
            browserConnectionCallback,
            null
        ).apply {
            connect()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")

        // 处理自定义“词”按钮
        if (intent?.action == ACTION_TOGGLE_LYRIC) {
            handleToggleLyric()
            return START_STICKY
        }

        // 如果已经有 controller 且有状态，确保前台通知存在
        mediaController?.let {
            updateNotification(it.metadata, it.playbackState)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        mediaController?.unregisterCallback(controllerCallback)
        mediaBrowser?.disconnect()
        mediaBrowser = null
        mediaController = null
        stopForeground(true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private val browserConnectionCallback = object : MediaBrowserCompat.ConnectionCallback() {
        override fun onConnected() {
            Log.d(TAG, "MediaBrowser connected")
            try {
                val browser = mediaBrowser ?: return
                val token = browser.sessionToken
                val controller = MediaControllerCompat(this@CustomMediaNotificationService, token)
                mediaController = controller
                controller.registerCallback(controllerCallback)

                // 初始化时立即更新一次通知
                updateNotification(controller.metadata, controller.playbackState)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create MediaController: ${e.message}", e)
            }
        }

        override fun onConnectionSuspended() {
            Log.w(TAG, "MediaBrowser connection suspended")
        }

        override fun onConnectionFailed() {
            Log.e(TAG, "MediaBrowser connection failed")
        }
    }

    private val controllerCallback = object : MediaControllerCompat.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadataCompat?) {
            Log.d(TAG, "onMetadataChanged: $metadata")
            currentMetadata = metadata
            updateNotification(metadata, currentState)
        }

        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) {
            Log.d(TAG, "onPlaybackStateChanged: $state")
            currentState = state
            updateNotification(currentMetadata, state)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Cyrene Music 媒体播放控制"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun updateNotification(
        metadata: MediaMetadataCompat?,
        state: PlaybackStateCompat?
    ) {
        val controller = mediaController ?: return
        val playbackState = state ?: controller.playbackState
        val mediaMeta = metadata ?: controller.metadata

        if (playbackState == null || mediaMeta == null) {
            Log.w(TAG, "No playback state or metadata, skipping notification update")
            return
        }

        val description: MediaDescriptionCompat = mediaMeta.description
        val isPlaying = playbackState.state == PlaybackStateCompat.STATE_PLAYING

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(description.title ?: "Cyrene Music")
            .setContentText(description.subtitle ?: description.description)
            .setSubText(description.extras?.getString("album"))
            .setWhen(playbackState.lastPositionUpdateTime)
            .setShowWhen(false)
            .setOngoing(isPlaying)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(createContentIntent())

        // 封面图
        val artBitmap: Bitmap? = description.iconBitmap ?: loadIconFromUri(description.iconUri)
        artBitmap?.let { builder.setLargeIcon(it) }

        // 媒体按钮 actions（顺序：上一首 / 播放(暂停) / 下一首 / 词）
        addNotificationActions(builder, isPlaying)

        // MediaStyle 绑定 MediaSession，紧凑视图最多支持 3 个按钮
        // 这里选择显示：播放(暂停)、下一首、词（去掉上一首），保证“词”按钮在紧凑视图中可见
        val style = MediaStyle()
            .setMediaSession(controller.sessionToken)
            .setShowActionsInCompactView(1, 2, 3)

        builder.setStyle(style)

        val notification: Notification = builder.build()

        // 启动或更新前台服务
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        Log.d(TAG, "Notification updated - playing=$isPlaying, title=${description.title}")
    }

    private fun addNotificationActions(builder: NotificationCompat.Builder, isPlaying: Boolean) {
        val controller = mediaController ?: return
        val sessionActivity = controller.sessionActivity

        // 上一首
        val prevIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this,
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        )
        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_media_previous,
                "上一首",
                prevIntent
            )
        )

        // 播放/暂停
        val playPauseAction = if (isPlaying) {
            android.R.drawable.ic_media_pause to PlaybackStateCompat.ACTION_PAUSE
        } else {
            android.R.drawable.ic_media_play to PlaybackStateCompat.ACTION_PLAY
        }
        val playPauseIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this,
            playPauseAction.second
        )
        builder.addAction(
            NotificationCompat.Action(
                playPauseAction.first,
                if (isPlaying) "暂停" else "播放",
                playPauseIntent
            )
        )

        // 下一首
        val nextIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this,
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        )
        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_media_next,
                "下一首",
                nextIntent
            )
        )

        // “词”按钮：用于切换悬浮歌词
        val lyricIntent = Intent(this, CustomMediaNotificationService::class.java).apply {
            action = ACTION_TOGGLE_LYRIC
        }
        val lyricPendingIntent = PendingIntent.getService(
            this,
            100,
            lyricIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        builder.addAction(
            NotificationCompat.Action(
                // 使用系统带感叹号的图标，适配不支持自定义图标的界面
                android.R.drawable.ic_dialog_alert,
                "词",
                lyricPendingIntent
            )
        )

        // 如果有自定义 sessionActivity，则用于通知点击行为
        if (sessionActivity != null) {
            builder.setContentIntent(sessionActivity)
        }
    }

    private fun createContentIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)

        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun loadIconFromUri(uri: android.net.Uri?): Bitmap? {
        if (uri == null) return null
        return try {
            val stream = contentResolver.openInputStream(uri)
            stream?.use { BitmapFactory.decodeStream(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load icon from uri: $uri, ${e.message}")
            null
        }
    }

    /**
     * 处理“词”按钮点击：通过 MediaController 向 audio_service 发送自定义指令，
     * 由 Dart 侧的 CyreneAudioHandler.customAction 去真正打开/关闭悬浮歌词。
     */
    private fun handleToggleLyric() {
        val controller = mediaController
        if (controller == null) {
            Log.w(TAG, "handleToggleLyric: mediaController is null")
            return
        }

        try {
            controller.transportControls.sendCustomAction("toggle_floating_lyric", null)
            Log.d(TAG, "handleToggleLyric: sent customAction toggle_floating_lyric")
        } catch (e: Exception) {
            Log.e(TAG, "handleToggleLyric failed: ${e.message}", e)
        }
    }
}

