package com.kasmtech.kasmvnc.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kasmtech.kasmvnc.domain.ServerProfile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.serverDataStore by preferencesDataStore("server_profiles")

class ServerRepository(private val context: Context) {
    private val key = stringPreferencesKey("profiles")
    private val json = Json { ignoreUnknownKeys = true }
    val profiles: Flow<List<ServerProfile>> = context.serverDataStore.data.map { prefs ->
        runCatching { json.decodeFromString<List<ServerProfile>>(prefs[key].orEmpty()) }.getOrDefault(emptyList())
    }
    suspend fun save(profile: ServerProfile) = context.serverDataStore.edit { prefs ->
        val current = runCatching { json.decodeFromString<List<ServerProfile>>(prefs[key].orEmpty()) }.getOrDefault(emptyList())
        prefs[key] = json.encodeToString((current.filterNot { it.id == profile.id } + profile).sortedBy { it.name.lowercase() })
    }
    suspend fun delete(id: String) = context.serverDataStore.edit { prefs ->
        val current = runCatching { json.decodeFromString<List<ServerProfile>>(prefs[key].orEmpty()) }.getOrDefault(emptyList())
        prefs[key] = json.encodeToString(current.filterNot { it.id == id })
    }
}
