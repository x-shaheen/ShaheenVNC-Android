package com.kasmtech.kasmvnc.domain

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ConnectionManager(private val scope: CoroutineScope) {
    private val _state = MutableStateFlow(ConnectionState.Idle)
    val state: StateFlow<ConnectionState> = _state.asStateFlow()
    private var retryJob: Job? = null
    fun connecting() { retryJob?.cancel(); _state.value = ConnectionState.Connecting }
    fun connected() { retryJob?.cancel(); _state.value = ConnectionState.Connected }
    fun disconnected() { _state.value = ConnectionState.Disconnected }
    fun error() { _state.value = ConnectionState.Error }
    fun reconnect(onRetry: () -> Unit) {
        retryJob?.cancel()
        retryJob = scope.launch {
            for (attempt in 0 until 5) {
                _state.value = ConnectionState.Reconnecting
                delay(1000L shl attempt)
                onRetry()
            }
            _state.value = ConnectionState.Error
        }
    }
    fun cancelReconnect() { retryJob?.cancel(); _state.value = ConnectionState.Disconnected }
}
