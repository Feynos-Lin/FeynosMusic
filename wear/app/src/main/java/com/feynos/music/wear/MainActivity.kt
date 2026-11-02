package com.feynos.music.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.*
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import kotlinx.coroutines.delay
import kotlin.math.abs

private val Accent = Color(0xFFA970FF)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PhoneLink.init(this)
        setContent { WearApp() }
    }

    override fun onResume() {
        super.onResume()
        PhoneLink.resume()
    }

    override fun onPause() {
        super.onPause()
        PhoneLink.pause()
    }
}

@Composable
fun WearApp() {
    MaterialTheme(colors = Colors(primary = Accent, primaryVariant = Accent, secondary = Accent)) {
        val nav = rememberSwipeDismissableNavController()
        SwipeDismissableNavHost(navController = nav, startDestination = "now") {
            composable("now") {
                NowPlayingScreen(onLibrary = { nav.navigate("library") }, onQueue = { nav.navigate("queue") })
            }
            composable("library") { LibraryScreen(onOpen = { nav.navigate("list/$it") }, onPlayed = { nav.popBackStack("now", false) }) }
            composable("list/{section}") { entry ->
                ListScreen(entry.arguments?.getString("section") ?: "", onPlayed = { nav.popBackStack("now", false) })
            }
            composable("queue") { QueueScreen(onPlayed = { nav.popBackStack("now", false) }) }
        }
    }
}

// ======================= Now playing =======================

@Composable
fun NowPlayingScreen(onLibrary: () -> Unit, onQueue: () -> Unit) {
    val s by PhoneLink.now.collectAsStateWithLifecycle()
    val status by PhoneLink.status.collectAsStateWithLifecycle()
    val got by PhoneLink.gotState.collectAsStateWithLifecycle()
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            tick = System.currentTimeMillis()
            delay(500)
        }
    }
    // Rotating the crown (or bezel) changes the phone's volume.
    val focus = remember { FocusRequester() }
    var volShownAt by remember { mutableLongStateOf(0L) }
    var acc by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) { focus.requestFocus() }

    Scaffold(timeText = { TimeText() }, vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) }) {
        Box(
            Modifier.fillMaxSize()
                .onRotaryScrollEvent { e ->
                    acc += e.verticalScrollPixels
                    if (abs(acc) > 40f) {
                        PhoneLink.volume(if (acc > 0) 1 else -1)
                        acc = 0f
                        volShownAt = System.currentTimeMillis()
                    }
                    true
                }
                .focusRequester(focus)
                .focusable(),
            contentAlignment = Alignment.Center,
        ) {
            if (!got || !s.has) {
                Waiting(status, got, onLibrary)
                return@Box
            }
            s.cover?.let {
                Image(it, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().alpha(0.4f))
            }
            Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(Color.Black.copy(alpha = 0.3f), Color.Black.copy(alpha = 0.85f)))))
            // Song progress around the edge of the screen.
            val progress = if (s.dur > 0) (s.positionAt(tick).toFloat() / s.dur).coerceIn(0f, 1f) else 0f
            CircularProgressIndicator(
                progress = progress, modifier = Modifier.fillMaxSize().padding(2.dp),
                startAngle = 295f, endAngle = 245f, strokeWidth = 4.dp, indicatorColor = Accent, trackColor = Color.White.copy(alpha = 0.15f),
            )
            val showVol = System.currentTimeMillis() - volShownAt < 1500 || tick - volShownAt < 1500
            Column(Modifier.fillMaxWidth().padding(horizontal = 22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                if (s.guest) Text("JAM", color = Accent, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                Text(s.title, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
                Text(
                    if (showVol) "Volume ${s.vol} / ${s.volMax}" else s.artist,
                    fontSize = 12.sp, color = if (showVol) Accent else Color.White.copy(alpha = 0.7f),
                    maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Button(onClick = { PhoneLink.send("previous") }, colors = ButtonDefaults.secondaryButtonColors(), modifier = Modifier.size(ButtonDefaults.SmallButtonSize)) {
                        Icon(Icons.Rounded.SkipPrevious, "Previous")
                    }
                    Button(onClick = { PhoneLink.toggle() }, modifier = Modifier.size(ButtonDefaults.LargeButtonSize)) {
                        if (s.buffering && s.playing) CircularProgressIndicator(Modifier.size(28.dp), indicatorColor = Color.Black, strokeWidth = 3.dp)
                        else Icon(if (s.playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (s.playing) "Pause" else "Play", modifier = Modifier.size(34.dp))
                    }
                    Button(onClick = { PhoneLink.send("next") }, colors = ButtonDefaults.secondaryButtonColors(), modifier = Modifier.size(ButtonDefaults.SmallButtonSize)) {
                        Icon(Icons.Rounded.SkipNext, "Next")
                    }
                }
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    CompactButton(onClick = { PhoneLink.like() }, colors = ButtonDefaults.iconButtonColors()) {
                        Icon(if (s.liked) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, "Like", tint = if (s.liked) Accent else Color.White)
                    }
                    CompactButton(onClick = onQueue, colors = ButtonDefaults.iconButtonColors()) {
                        Icon(Icons.AutoMirrored.Rounded.QueueMusic, "Up next")
                    }
                    CompactButton(onClick = onLibrary, colors = ButtonDefaults.iconButtonColors()) {
                        Icon(Icons.Rounded.LibraryMusic, "Library")
                    }
                }
            }
        }
    }
}

/** Shown before the phone has answered, or when nothing is playing. */
@Composable
private fun Waiting(status: LinkStatus, got: Boolean, onLibrary: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Rounded.MusicNote, null, tint = Accent, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(6.dp))
        val msg = when {
            status == LinkStatus.SEARCHING && !got -> "Connecting to your phone…"
            status == LinkStatus.NO_PHONE -> "Can't reach Feynos Music on your phone. Make sure it's installed and the phone is nearby."
            !got -> "Open Feynos Music on your phone."
            else -> "Nothing playing"
        }
        Text(msg, textAlign = TextAlign.Center, fontSize = 13.sp)
        Spacer(Modifier.height(8.dp))
        if (got && status == LinkStatus.CONNECTED) {
            Chip(onClick = onLibrary, label = { Text("Browse music") }, icon = { Icon(Icons.Rounded.LibraryMusic, null) }, colors = ChipDefaults.primaryChipColors())
        } else if (status != LinkStatus.SEARCHING) {
            CompactChip(onClick = { PhoneLink.connect() }, label = { Text("Try again") }, icon = { Icon(Icons.Rounded.Refresh, null) })
        }
    }
}

// ======================= Library =======================

@Composable
fun LibraryScreen(onOpen: (String) -> Unit, onPlayed: () -> Unit) {
    val state = rememberScalingLazyListState()
    Scaffold(timeText = { TimeText() }, positionIndicator = { PositionIndicator(state) }) {
        ScalingLazyColumn(state = state, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text("Library") } }
            item {
                Chip(
                    onClick = { PhoneLink.send("play", "kind" to "shuffle", "id" to ""); onPlayed() },
                    label = { Text("Shuffle all") }, icon = { Icon(Icons.Rounded.Shuffle, null) },
                    colors = ChipDefaults.primaryChipColors(), modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Chip(
                    onClick = { PhoneLink.send("play", "kind" to "liked", "id" to "", "shuffle" to "1"); onPlayed() },
                    label = { Text("Liked songs") }, icon = { Icon(Icons.Rounded.Favorite, null) },
                    colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
                )
            }
            val sections = listOf(
                Triple("pinned", "Pinned", Icons.Rounded.PushPin),
                Triple("mixes", "Made for you", Icons.Rounded.AutoAwesome),
                Triple("playlists", "Playlists", Icons.AutoMirrored.Rounded.QueueMusic),
                Triple("recent", "Recently played", Icons.Rounded.History),
                Triple("newest", "Recently added", Icons.Rounded.NewReleases),
                Triple("albums", "Liked albums", Icons.Rounded.Album),
            )
            items(sections) { (id, label, icon) ->
                Chip(
                    onClick = { onOpen(id) }, label = { Text(label) }, icon = { Icon(icon, null) },
                    colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

private fun sectionTitle(section: String) = when (section) {
    "pinned" -> "Pinned"
    "mixes" -> "Made for you"
    "playlists" -> "Playlists"
    "recent" -> "Recently played"
    "newest" -> "Recently added"
    "albums" -> "Liked albums"
    else -> "Music"
}

@Composable
fun ListScreen(section: String, onPlayed: () -> Unit) {
    val lists by PhoneLink.lists.collectAsStateWithLifecycle()
    val items = lists[section]
    LaunchedEffect(section) { PhoneLink.browse(section) }
    val state = rememberScalingLazyListState()
    Scaffold(timeText = { TimeText() }, positionIndicator = { PositionIndicator(state) }) {
        ScalingLazyColumn(state = state, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text(sectionTitle(section)) } }
            when {
                items == null -> item { CircularProgressIndicator(Modifier.size(32.dp), indicatorColor = Accent) }
                items.isEmpty() -> item {
                    Text(
                        if (section == "pinned") "Pin albums or playlists in the phone app to see them here." else "Nothing here yet",
                        textAlign = TextAlign.Center, fontSize = 13.sp, modifier = Modifier.padding(12.dp),
                    )
                }
                else -> items(items) { b ->
                    Chip(
                        onClick = { PhoneLink.send("play", "kind" to b.kind, "id" to b.id); onPlayed() },
                        label = { Text(b.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        secondaryLabel = if (b.sub.isNotBlank()) ({ Text(b.sub, maxLines = 1, overflow = TextOverflow.Ellipsis) }) else null,
                        icon = {
                            Icon(
                                when (b.kind) {
                                    "playlist" -> Icons.AutoMirrored.Rounded.QueueMusic
                                    "mix" -> Icons.Rounded.AutoAwesome
                                    else -> Icons.Rounded.Album
                                },
                                null,
                            )
                        },
                        colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

// ======================= Up next =======================

@Composable
fun QueueScreen(onPlayed: () -> Unit) {
    val s by PhoneLink.now.collectAsStateWithLifecycle()
    val state = rememberScalingLazyListState()
    Scaffold(timeText = { TimeText() }, positionIndicator = { PositionIndicator(state) }) {
        ScalingLazyColumn(state = state, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text("Up next") } }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CompactButton(
                        onClick = { PhoneLink.send("shuffle") },
                        colors = if (s.shuffle) ButtonDefaults.primaryButtonColors() else ButtonDefaults.secondaryButtonColors(),
                    ) { Icon(Icons.Rounded.Shuffle, "Shuffle") }
                    CompactButton(
                        onClick = { PhoneLink.send("repeat") },
                        colors = if (s.repeat != 0) ButtonDefaults.primaryButtonColors() else ButtonDefaults.secondaryButtonColors(),
                    ) { Icon(if (s.repeat == 1) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat, "Repeat") }
                }
            }
            if (s.next.isEmpty()) {
                item { Text("Nothing queued", fontSize = 13.sp, modifier = Modifier.padding(12.dp)) }
            }
            items(s.next) { n ->
                Chip(
                    onClick = { PhoneLink.send("skipTo", "i" to n.index); onPlayed() },
                    label = { Text(n.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    secondaryLabel = { Text(n.artist, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
