package com.realowho.app.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.realowho.app.auth.MarketplaceAuthException
import com.realowho.app.auth.MarketplaceSessionStore
import com.realowho.app.auth.UserRole
import com.realowho.app.marketplace.SaleCoordinationStore
import kotlinx.coroutines.launch

enum class AuthMode(val title: String) {
    SIGN_IN("Sign In"),
    CREATE_ACCOUNT("Create Account")
}

private enum class DemoAccessAccount(
    val title: String,
    val subtitle: String,
    val email: String,
    val password: String
) {
    BUYER(
        title = "Demo Buyer",
        subtitle = "Noah Chen",
        email = "noah@realowho.app",
        password = "HouseDeal123!"
    ),
    SELLER(
        title = "Demo Seller",
        subtitle = "Mason Wright",
        email = "mason@realowho.app",
        password = "HouseDeal123!"
    )
}

private object LegalLinks {
    const val WEBSITE = "https://roper8883.github.io/Real-O-Who/real-o-who/"
    const val PRIVACY = "https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/"
    const val TERMS = "https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/"
    const val SUPPORT = "https://roper8883.github.io/Real-O-Who/real-o-who/support/"
}

@Composable
fun AuthenticationScreen(
    store: MarketplaceSessionStore,
    saleStore: SaleCoordinationStore,
    prefilledLegalInviteCode: String? = null,
    externalErrorMessage: String? = null,
    initialMode: AuthMode = AuthMode.CREATE_ACCOUNT,
    onAuthSuccess: () -> Unit = {}
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var modeName by rememberSaveable { mutableStateOf(initialMode.name) }
    val mode = AuthMode.valueOf(modeName)

    var signInEmail by rememberSaveable { mutableStateOf("") }
    var signInPassword by rememberSaveable { mutableStateOf("") }

    var createName by rememberSaveable { mutableStateOf("") }
    var createEmail by rememberSaveable { mutableStateOf("") }
    var createPassword by rememberSaveable { mutableStateOf("") }
    var createSuburb by rememberSaveable { mutableStateOf("Brisbane") }
    var createRoleName by rememberSaveable { mutableStateOf(UserRole.SELLER.name) }
    val createRole = UserRole.valueOf(createRoleName)
    var legalInviteCode by rememberSaveable { mutableStateOf("") }

    var errorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var isSubmitting by rememberSaveable { mutableStateOf(false) }
    var isOpeningInvite by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(prefilledLegalInviteCode) {
        val inviteCode = prefilledLegalInviteCode?.trim()?.uppercase()
        if (!inviteCode.isNullOrEmpty()) {
            legalInviteCode = inviteCode
        }
    }

    LaunchedEffect(externalErrorMessage) {
        if (!externalErrorMessage.isNullOrBlank()) {
            errorMessage = externalErrorMessage
        }
    }

    LaunchedEffect(initialMode) {
        modeName = initialMode.name
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFFE8F6FF),
                        Color(0xFFF7FBFF)
                    )
                )
            )
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                HeroCard(
                    title = "Real O Who",
                    subtitle = "Private property, no agent-sized commission.",
                    body = "Create an account, or open a legal workspace invite if you are the conveyancer or solicitor handling the sale."
                )
            }

            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        AuthMode.entries.forEach { authMode ->
                            FilterChip(
                                selected = mode == authMode,
                                onClick = {
                                    modeName = authMode.name
                                    errorMessage = null
                                },
                                label = { Text(authMode.title) }
                            )
                        }
                    }
                }
            }

            item {
                MessageCard(
                    title = "Quick demo access",
                    body = "Use the seeded buyer or seller account when the local backend is running. Both use the password HouseDeal123!.",
                    accent = Color(0xFF15808A)
                )
            }

            item {
                AuthPanel(title = "Legal workspace invite") {
                    Text(
                        text = "Conveyancers and solicitors can open the limited legal workspace with the invite code shared from the sale. Invite codes activate on first use and expire after 30 days.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "Invite links can open this workspace directly. If the app lands here instead, the invite code will already be filled in.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = legalInviteCode,
                        onValueChange = { legalInviteCode = it.uppercase() },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Invite code") }
                    )
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                isOpeningInvite = true
                                errorMessage = null
                                try {
                                    val didOpen = saleStore.openLegalWorkspace(legalInviteCode)
                                    if (!didOpen) {
                                        errorMessage = "That legal workspace invite could not be found yet."
                                    }
                                } catch (error: Exception) {
                                    errorMessage = error.message ?: "Could not open the legal workspace right now."
                                } finally {
                                    isOpeningInvite = false
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !isOpeningInvite && legalInviteCode.isNotBlank()
                    ) {
                        Text(if (isOpeningInvite) "Opening..." else "Open Legal Workspace")
                    }
                }
            }

            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(
                        modifier = Modifier.padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        DemoAccessAccount.entries.forEach { account ->
                            TextButton(
                                onClick = {
                                    modeName = AuthMode.SIGN_IN.name
                                    errorMessage = null
                                    signInEmail = account.email
                                    signInPassword = account.password
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.fillMaxWidth()) {
                                    Text(
                                        text = account.title,
                                        style = MaterialTheme.typography.titleSmall,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text(
                                        text = account.subtitle,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = account.email,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if (errorMessage != null) {
                item {
                    MessageCard(
                        title = "Check this first",
                        body = errorMessage.orEmpty(),
                        accent = Color(0xFFD1495B)
                    )
                }
            }

            item {
                if (mode == AuthMode.SIGN_IN) {
                    AuthPanel(title = "Welcome back") {
                        OutlinedTextField(
                            value = signInEmail,
                            onValueChange = { signInEmail = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Email") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                        )
                        OutlinedTextField(
                            value = signInPassword,
                            onValueChange = { signInPassword = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Password") },
                            visualTransformation = PasswordVisualTransformation()
                        )
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    isSubmitting = true
                                    errorMessage = null
                                    try {
                                        store.signIn(signInEmail, signInPassword)
                                        onAuthSuccess()
                                    } catch (error: MarketplaceAuthException) {
                                        errorMessage = error.message
                                    } finally {
                                        isSubmitting = false
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isSubmitting && signInEmail.isNotBlank() && signInPassword.isNotBlank()
                        ) {
                            Text(if (isSubmitting) "Signing In..." else "Sign In")
                        }
                        Text(
                            text = "Backend accounts work when the local server is running. Otherwise, device-only accounts still work.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    AuthPanel(title = "Create your launch account") {
                        OutlinedTextField(
                            value = createName,
                            onValueChange = { createName = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Full name") }
                        )
                        OutlinedTextField(
                            value = createEmail,
                            onValueChange = { createEmail = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Email") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                        )
                        OutlinedTextField(
                            value = createPassword,
                            onValueChange = { createPassword = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Password (8+ characters)") },
                            visualTransformation = PasswordVisualTransformation()
                        )
                        OutlinedTextField(
                            value = createSuburb,
                            onValueChange = { createSuburb = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text("Suburb") }
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            UserRole.entries.forEach { role ->
                                FilterChip(
                                    selected = createRole == role,
                                    onClick = { createRoleName = role.name },
                                    label = { Text(if (role == UserRole.BUYER) "Buy property" else "Sell property") }
                                )
                            }
                        }
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    isSubmitting = true
                                    errorMessage = null
                                    try {
                                        store.createAccount(
                                            name = createName,
                                            email = createEmail,
                                            password = createPassword,
                                            role = createRole,
                                            suburb = createSuburb
                                        )
                                        onAuthSuccess()
                                    } catch (error: MarketplaceAuthException) {
                                        errorMessage = error.message
                                    } finally {
                                        isSubmitting = false
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isSubmitting &&
                                createName.isNotBlank() &&
                                createEmail.isNotBlank() &&
                                createPassword.isNotBlank() &&
                                createSuburb.isNotBlank()
                        ) {
                            Text(if (isSubmitting) "Creating..." else "Create Account")
                        }
                    }
                }
            }

            item {
                MessageCard(
                    title = "Launch-ready storage",
                    body = "When the local backend is running, sign-in and create-account use the API automatically. If it is offline, this Android build falls back to on-device storage.",
                    accent = Color(0xFF198F7A)
                )
            }

            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(
                        modifier = Modifier.padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            text = "Website and legal",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        LinkButton("Website", context, LegalLinks.WEBSITE)
                        LinkButton("Privacy Policy", context, LegalLinks.PRIVACY)
                        LinkButton("Terms of Use", context, LegalLinks.TERMS)
                        LinkButton("Support", context, LegalLinks.SUPPORT)
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroCard(title: String, subtitle: String, body: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF0A3848),
                            Color(0xFF118D88),
                            Color(0xFF4FB7E4)
                        )
                    )
                )
                .padding(22.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
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
}

@Composable
private fun AuthPanel(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                content()
            }
        )
    }
}

@Composable
fun MessageCard(title: String, body: String, accent: Color) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = accent
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun LinkButton(label: String, context: Context, url: String) {
    TextButton(onClick = { openLink(context, url) }) {
        Text(label)
    }
}

private fun openLink(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
    }
}
