package com.feynos.music.wear

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject

/** One song in the phone's up next list. */
data class NextItem(val index: Int, val title: String, val artist: String)

/** What the phone is playing, as last reported. */
data class NowState(
    val has: Boolean = false,
    val id: String = "",
    val title: String = "",
    val artist: String = "",
    val album: String = "",
    val playing: Boolean = false,
    val buffering: Boolean = false,
    val pos: Long = 0,
    val dur: Long = 0,
    val at: Long = 0,
    val shuffle: Boolean = false,
    val repeat: Int = 0, // 0 off, 1 one, 2 all
    val liked: Boolean = false,
    val vol: Int = 0,
    val volMax: Int = 15,
    val guest: Boolean = false,
    val next: List<NextItem> = emptyList(),
    val cover: ImageBitmap? = null,
) {
    /** Position now, counting the time since the phone last reported. */
    fun positionAt(now: Long): Long = if (playing && at > 0) (pos + (now - at)).coerceAtMost(if (dur > 0) dur else Long.MAX_VALUE) else pos
}

/** A row in a library list on the watch. */
data class BrowseItem(val kind: String, val id: String, val title: String, val sub: String)

enum class LinkStatus { SEARCHING, NO_PHONE, CONNECTED }

/**
 * Talks to Feynos Music on the paired phone over the Wear OS Data Layer: the phone shares what's
 * playing, and the watch sends commands and asks for library lists.
 */
object PhoneLink : DataClient.OnDataChangedListener, MessageClient.OnMessageReceivedListener {
    private const val PATH_NOW = "/feynos/now"
    private const val PATH_CMD = "/feynos/cmd"
    private const val PATH_LIST = "/feynos/list"
    private const val CAPABILITY = "feynos_music_phone"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var app: Context
    private var node: String? = null

    private val _now = MutableStateFlow(NowState())
    val now: StateFlow<NowState> = _now.asStateFlow()
    private val _status = MutableStateFlow(LinkStatus.SEARCHING)
    val status: StateFlow<LinkStatus> = _status.asStateFlow()
    private val _gotState = MutableStateFlow(false)
    /** True once the phone app has answered at least once. */
    val gotState: StateFlow<Boolean> = _gotState.asStateFlow()
    private val _lists = MutableStateFlow<Map<String, List<BrowseItem>>>(emptyMap())
    val lists: StateFlow<Map<String, List<BrowseItem>>> = _lists.asStateFlow()

    fun init(context: Context) {
        app = context.applicationContext
    }

    /** Starts listening (while the app is on screen) and asks the phone for the latest state. */
    fun resume() {
        Wearable.getDataClient(app).addListener(this)
        Wearable.getMessageClient(app).addListener(this)
        scope.launch {
            // Show the last known state straight away.
            runCatching {
                val items = Wearable.getDataClient(app).getDataItems(Uri.Builder().scheme("wear").path(PATH_NOW).build()).await()
                items.firstOrNull()?.let { apply(DataMapItem.fromDataItem(it).dataMap) }
                items.release()
            }
            connect()
        }
    }

    fun pause() {
        Wearable.getDataClient(app).removeListener(this)
        Wearable.getMessageClient(app).removeListener(this)
    }

    /** Finds the phone with Feynos Music and says hello so it sends fresh state. */
    fun connect() {
        scope.launch {
            _status.value = LinkStatus.SEARCHING
            node = runCatching {
                Wearable.getCapabilityClient(app).getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE).await()
                    .nodes.let { n -> n.firstOrNull { it.isNearby } ?: n.firstOrNull() }?.id
            }.getOrNull()
            _status.value = if (node == null) LinkStatus.NO_PHONE else LinkStatus.CONNECTED
            if (node != null) send("hello")
        }
    }

    fun send(op: String, vararg extra: Pair<String, Any>) {
        scope.launch {
            val target = node ?: return@launch
            val body = JSONObject().put("op", op)
            extra.forEach { (k, v) -> body.put(k, v) }
            runCatching { Wearable.getMessageClient(app).sendMessage(target, PATH_CMD, body.toString().toByteArray()).await() }
                .onFailure { _status.value = LinkStatus.NO_PHONE }
        }
    }

    fun browse(section: String) = send("browse", "section" to section)

    // Quick local updates so buttons feel instant; the phone's next update confirms them.
    fun toggle() {
        _now.update { it.copy(playing = !it.playing, pos = it.positionAt(System.currentTimeMillis()), at = System.currentTimeMillis()) }
        send("toggle")
    }

    fun like() {
        _now.update { it.copy(liked = !it.liked) }
        send("like")
    }

    fun volume(dir: Int) {
        _now.update { it.copy(vol = (it.vol + dir).coerceIn(0, it.volMax)) }
        send("vol", "dir" to dir)
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.forEach { e ->
            if (e.dataItem.uri.path == PATH_NOW) apply(DataMapItem.fromDataItem(e.dataItem).dataMap)
        }
    }

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PATH_LIST) return
        runCatching {
            val o = JSONObject(String(event.data))
            val arr = o.getJSONArray("items")
            val items = (0 until arr.length()).map { i ->
                val it = arr.getJSONObject(i)
                BrowseItem(it.optString("k"), it.optString("id"), it.optString("t"), it.optString("s"))
            }
            _lists.update { it + (o.getString("section") to items) }
        }
    }

    private fun apply(m: DataMap) {
        val next = runCatching {
            val a = JSONArray(m.getString("next", "[]"))
            (0 until a.length()).map { i -> a.getJSONObject(i).let { NextItem(it.optInt("i"), it.optString("t"), it.optString("a")) } }
        }.getOrDefault(emptyList())
        val newId = m.getString("id", "")
        val keepCover = if (newId == _now.value.id) _now.value.cover else null
        _now.value = NowState(
            has = m.getBoolean("has"), id = newId, title = m.getString("title", ""), artist = m.getString("artist", ""),
            album = m.getString("album", ""), playing = m.getBoolean("playing"), buffering = m.getBoolean("buffering"),
            pos = m.getLong("pos"), dur = m.getLong("dur"), at = System.currentTimeMillis(),
            shuffle = m.getBoolean("shuffle"), repeat = m.getInt("repeat"), liked = m.getBoolean("liked"),
            vol = m.getInt("vol"), volMax = m.getInt("volMax", 15).coerceAtLeast(1), guest = m.getBoolean("guest"),
            next = next, cover = keepCover,
        )
        _gotState.value = true
        _status.value = LinkStatus.CONNECTED
        val asset = m.getAsset("cover") ?: return
        scope.launch(Dispatchers.IO) {
            val bmp = runCatching {
                Wearable.getDataClient(app).getFdForAsset(asset).await().inputStream.use { BitmapFactory.decodeStream(it) }
            }.getOrNull() ?: return@launch
            _now.update { if (it.id == newId) it.copy(cover = bmp.asImageBitmap()) else it }
        }
    }
}
