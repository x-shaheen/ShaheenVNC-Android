package com.kasmtech.kasmvnc.domain

import android.net.Uri
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class ServerProfile(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val url: String,
    val useHttps: Boolean = true,
    val autoConnect: Boolean = false,
    val fullscreen: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

enum class ConnectionState { Idle, Connecting, Connected, Reconnecting, Disconnected, Error }

data class ValidationResult(val valid: Boolean, val message: String? = null)

object ServerValidator {
    private val localHosts = setOf("localhost", "127.0.0.1", "10.0.2.2", "::1")
    fun validateUrl(raw: String, debug: Boolean): ValidationResult {
        val value = raw.trim()
        val uri = runCatching { Uri.parse(value) }.getOrNull()
            ?: return ValidationResult(false, "Enter a valid server URL")
        val scheme = uri.scheme?.lowercase()
        val host = uri.host?.lowercase()
        if (host.isNullOrBlank() || uri.userInfo != null) return ValidationResult(false, "URL must include a trusted host")
        if (scheme != "https" && !(debug && scheme == "http" && host in localHosts)) {
            return ValidationResult(false, "HTTPS is required (HTTP is limited to local debug hosts)")
        }
        if (uri.fragment != null || uri.query != null) return ValidationResult(false, "URL must not contain a query or fragment")
        return ValidationResult(true)
    }
    fun validateProfile(profile: ServerProfile, debug: Boolean): ValidationResult {
        if (profile.name.trim().length !in 1..80) return ValidationResult(false, "Name must be between 1 and 80 characters")
        return validateUrl(profile.url, debug)
    }
    fun isAllowedNavigation(target: String, origin: String): Boolean {
        val uri = runCatching { Uri.parse(target) }.getOrNull() ?: return false
        val base = runCatching { Uri.parse(origin) }.getOrNull() ?: return false
        return uri.scheme in setOf("https", "http") && uri.host == base.host && uri.port.let { it == -1 || it == base.port }
    }
}
