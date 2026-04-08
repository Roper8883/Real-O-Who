package com.realowho.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF1F5A8E),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD9E9F4),
    onPrimaryContainer = Color(0xFF0D2941),
    secondary = Color(0xFF587B96),
    background = Color(0xFFF6F9FC),
    surface = Color.White,
    surfaceVariant = Color(0xFFEAF1F6),
    onSurfaceVariant = Color(0xFF314451)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF9CC6EB),
    onPrimary = Color(0xFF0B2740),
    primaryContainer = Color(0xFF1B4364),
    onPrimaryContainer = Color(0xFFD9E9F4),
    secondary = Color(0xFFB5C9D8),
    background = Color(0xFF11161B),
    surface = Color(0xFF161C22),
    surfaceVariant = Color(0xFF26323C),
    onSurfaceVariant = Color(0xFFD2DEE7)
)

@Composable
fun RealOWhoTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = Typography(),
        content = content
    )
}

