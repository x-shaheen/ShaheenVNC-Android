package com.kasmtech.kasmvnc

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

            setContent {
                ShaheenVNCApp()
            }
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    override fun onBackPressed() {
        moveTaskToBack(true)
    }
}

@Composable
private fun ShaheenVNCApp() {
    MaterialTheme {
        Surface(
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "ShaheenVNC",
                    style = MaterialTheme.typography.headlineMedium
                )

                Text(
                    text = "Application is running",
                    modifier = Modifier.padding(top = 16.dp)
                )

                Text(
                    text = "Runtime initialized successfully",
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}
