package com.kasmtech.kasmvnc

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import com.kasmtech.kasmvnc.data.ServerRepository
import com.kasmtech.kasmvnc.domain.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(state: Bundle?) { super.onCreate(state); enableEdgeToEdge(); setContent { KasmApp() } }
}

class ServerViewModel(private val repo: ServerRepository) : ViewModel() {
    val profiles = repo.profiles
    fun save(profile: ServerProfile) = viewModelScope.launch { repo.save(profile) }
    fun delete(id: String) = viewModelScope.launch { repo.delete(id) }
    companion object { fun factory(repo: ServerRepository) = object : ViewModelProvider.Factory { override fun <T : ViewModel> create(c: Class<T>): T = ServerViewModel(repo) as T } }
}

@Composable fun KasmApp() {
    val context = LocalContext.current
    val vm: ServerViewModel = viewModel(factory = ServerViewModel.factory(ServerRepository(context.applicationContext)))
    val nav = rememberNavController()
    MaterialTheme(colorScheme = darkColorScheme(primary = ColorTokens.Blue, secondary = ColorTokens.Teal)) {
        NavHost(navController = nav, startDestination = "servers") {
            composable("servers") { ServerListScreen(vm, { nav.navigate("add") }, { id -> nav.navigate("session/$id") }) }
            composable("add") { AddServerScreen(vm) { nav.popBackStack() } }
            composable("session/{id}") { entry ->
                val id = entry.arguments?.getString("id")
                val profile = vm.profiles.collectAsState(emptyList()).value.firstOrNull { it.id == id }
                if (profile != null) RemoteSessionScreen(profile) { nav.popBackStack() }
            }
        }
    }
}
private object ColorTokens { val Blue = androidx.compose.ui.graphics.Color(0xFF55B7F5); val Teal = androidx.compose.ui.graphics.Color(0xFF55D6BE) }

@Composable private fun ServerListScreen(vm: ServerViewModel, add: () -> Unit, connect: (String) -> Unit) {
    val profiles by vm.profiles.collectAsState(emptyList())
    Scaffold(topBar = { TopAppBar(title = { Text("KasmVNC Android") }, actions = { Icon(Icons.Default.Security, "Secure") }) }, floatingActionButton = { FloatingActionButton(onClick = add) { Icon(Icons.Default.Add, "Add server") } }) { padding ->
        LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text("My Servers", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 18.dp, bottom = 6.dp)) }
            if (profiles.isEmpty()) item { EmptyState(add) }
            items(profiles, key = { it.id }) { profile -> ServerCard(profile, { connect(profile.id) }, { vm.delete(profile.id) }) }
        }
    }
}
@Composable private fun EmptyState(add: () -> Unit) { Card { Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Default.Computer, null, Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary); Text("No saved connections", style = MaterialTheme.typography.titleLarge); Text("Add a trusted KasmVNC server to begin.", modifier = Modifier.padding(vertical = 8.dp)); OutlinedButton(onClick = add) { Text("Add Server") } } } }
@Composable private fun ServerCard(p: ServerProfile, connect: () -> Unit, remove: () -> Unit) { Card { Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) { Icon(Icons.Default.Computer, null, tint = MaterialTheme.colorScheme.primary); Column(Modifier.weight(1f)) { Text(p.name, style = MaterialTheme.typography.titleLarge); Text(p.url, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) } IconButton(onClick = remove) { Icon(Icons.Default.Delete, "Delete") } }; Button(onClick = connect, modifier = Modifier.fillMaxWidth()) { Text("CONNECT") } } } }

@Composable private fun AddServerScreen(vm: ServerViewModel, back: () -> Unit) {
    var name by remember { mutableStateOf("") }; var url by remember { mutableStateOf("https://") }; var auto by remember { mutableStateOf(false) }; var fullscreen by remember { mutableStateOf(false) }; var error by remember { mutableStateOf<String?>(null) }
    Scaffold(topBar = { TopAppBar(title = { Text("Add Server") }, navigationIcon = { IconButton(onClick = back) { Icon(Icons.Default.ArrowBack, "Back") } }) }) { pad -> Column(Modifier.padding(pad).padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Connection Name") }, singleLine = true)
        OutlinedTextField(url, { url = it }, Modifier.fillMaxWidth(), label = { Text("Server URL (HTTPS)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri), singleLine = true)
        Text("Only HTTPS is allowed in release builds. HTTP is limited to local debug hosts.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) { Text("Fullscreen default"); Switch(fullscreen, { fullscreen = it }) }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) { Text("Auto connect"); Switch(auto, { auto = it }) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Button(onClick = { val p = ServerProfile(name = name.trim(), url = url.trim(), autoConnect = auto, fullscreen = fullscreen); val result = ServerValidator.validateProfile(p, BuildConfig.DEBUG); if (result.valid) { vm.save(p); back() } else error = result.message }, Modifier.fillMaxWidth()) { Text("Save Server") }
    } }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable private fun RemoteSessionScreen(profile: ServerProfile, back: () -> Unit) {
    var status by remember { mutableStateOf(ConnectionState.Connecting) }; var fullscreen by remember { mutableStateOf(profile.fullscreen) }; val context = LocalContext.current
    DisposableEffect(profile) { onDispose { } }
    Scaffold(topBar = { TopAppBar(title = { Text(profile.name) }, navigationIcon = { IconButton(onClick = back) { Icon(Icons.Default.Close, "Disconnect") } }, actions = { Text(status.name); IconButton(onClick = { fullscreen = !fullscreen }) { Icon(Icons.Default.Fullscreen, "Fullscreen") } }) }) { pad ->
        AndroidView(factory = { ctx -> SecureKasmWebView(ctx, profile.url) { state -> status = state }.apply { layoutParams = ViewGroup.LayoutParams(-1, -1) } }, modifier = Modifier.padding(pad).fillMaxSize())
    }
}

private class SecureKasmWebView(context: android.content.Context, private val origin: String, onState: (ConnectionState) -> Unit) : WebView(context) {
    init { setBackgroundColor(android.graphics.Color.BLACK); settings.javaScriptEnabled = true; settings.domStorageEnabled = true; settings.databaseEnabled = false; settings.allowFileAccess = false; settings.allowContentAccess = false; settings.allowFileAccessFromFileURLs = false; settings.allowUniversalAccessFromFileURLs = false; settings.mediaPlaybackRequiresUserGesture = false; settings.safeBrowsingEnabled = true; setLayerType(View.LAYER_TYPE_HARDWARE, null); CookieManager.getInstance().setAcceptCookie(true); webViewClient = object : WebViewClient() {
        override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) { onState(ConnectionState.Connecting) }
        override fun onPageFinished(view: WebView, url: String) { onState(ConnectionState.Connected) }
        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) { onState(ConnectionState.Error) }
        override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: android.net.http.SslError) { handler.cancel(); onState(ConnectionState.Error) }
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = !ServerValidator.isAllowedNavigation(request.url.toString(), origin)
    }; loadUrl(origin) }
}
