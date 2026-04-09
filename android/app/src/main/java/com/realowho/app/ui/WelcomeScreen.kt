package com.realowho.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.realowho.app.auth.MarketplaceAuthException
import com.realowho.app.auth.MarketplaceSessionStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

private data class WelcomeDemoAccount(
    val email: String,
    val password: String
)

@Composable
fun WelcomeScreen(
    store: MarketplaceSessionStore,
    onContinue: () -> Unit,
    onSignIn: () -> Unit,
    onCreateAccount: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    var errorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var isSubmittingDemo by rememberSaveable { mutableStateOf(false) }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            WelcomeHero(
                title = "Welcome to Real O Who",
                subtitle = "Buy and sell privately in Australia without a full agency fee.",
                body = "Use the seeded demo to try every flow now, or create your own account to keep your data on this device."
            )
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier
                        .padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = { onContinue() },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Continue now")
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        TextButton(
                            onClick = onSignIn,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Sign in")
                        }
                        TextButton(
                            onClick = onCreateAccount,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Create account")
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        DemoAccessButton(
                            title = "Use demo buyer",
                            isSubmittingDemo = isSubmittingDemo,
                            onClick = {
                                runDemoSignIn(
                                    account = WelcomeDemoAccount(
                                        email = "noah@realowho.app",
                                        password = "HouseDeal123!"
                                    ),
                                    isSubmittingDemo = isSubmittingDemo,
                                    onStart = { isSubmittingDemo = true },
                                    onFinish = { isSubmittingDemo = false },
                                    onComplete = { onContinue() },
                                    setError = { errorMessage = it },
                                    store = store,
                                    coroutineScope = coroutineScope
                                )
                            },
                            modifier = Modifier.weight(1f)
                        )
                        DemoAccessButton(
                            title = "Use demo seller",
                            isSubmittingDemo = isSubmittingDemo,
                            onClick = {
                                runDemoSignIn(
                                    account = WelcomeDemoAccount(
                                        email = "mason@realowho.app",
                                        password = "HouseDeal123!"
                                    ),
                                    isSubmittingDemo = isSubmittingDemo,
                                    onStart = { isSubmittingDemo = true },
                                    onFinish = { isSubmittingDemo = false },
                                    onComplete = { onContinue() },
                                    setError = { errorMessage = it },
                                    store = store,
                                    coroutineScope = coroutineScope
                                )
                            },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        item {
            MessageCard(
                title = "For Apple and Google review",
                body = "Sign in is optional on launch. This app remains testable with seeded demo accounts and local storage.",
                accent = Color(0xFF118D88)
            )
        }

        if (errorMessage != null) {
            item {
                MessageCard(
                    title = "Demo sign-in failed",
                    body = errorMessage.orEmpty(),
                    accent = Color(0xFFD1495B)
                )
            }
        }
    }
}

@Composable
private fun WelcomeHero(title: String, subtitle: String, body: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        listOf(
                            Color(0xFF0A3848),
                            Color(0xFF118D88),
                            Color(0xFF4FB7E4)
                        )
                    )
                )
                .padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.86f)
            )
        }
    }
}

private fun runDemoSignIn(
    account: WelcomeDemoAccount,
    isSubmittingDemo: Boolean,
    onStart: () -> Unit,
    onFinish: () -> Unit,
    onComplete: () -> Unit,
    setError: (String?) -> Unit,
    store: MarketplaceSessionStore,
    coroutineScope: CoroutineScope
) {
    if (isSubmittingDemo) {
        return
    }

    setError(null)
    coroutineScope.launch {
        onStart()
        try {
            store.signIn(email = account.email, password = account.password)
            onComplete()
        } catch (error: MarketplaceAuthException) {
            setError(error.message ?: "Could not sign in with demo account.")
        } finally {
            onFinish()
        }
    }
}

@Composable
private fun DemoAccessButton(
    title: String,
    isSubmittingDemo: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        enabled = !isSubmittingDemo,
        modifier = modifier
    ) {
        if (isSubmittingDemo) {
            Text("$title...")
        } else {
            Text(title)
        }
    }
}
