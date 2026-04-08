package com.realowho.app.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Policy
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.AppTab
import com.realowho.app.data.ReflectionStore
import com.realowho.app.model.ReflectionEntry
import com.realowho.app.model.ReflectionMood
import com.realowho.app.model.ReflectionPrompt
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.launch

private enum class EntryFilter(val title: String) {
    ALL("All"),
    FAVORITES("Favorites")
}

private object LegalLinks {
    const val HOME = "https://roper8883.github.io/Real-A-Who/real-o-who/"
    const val PRIVACY = "https://roper8883.github.io/Real-A-Who/real-o-who/privacy-policy/"
    const val TERMS = "https://roper8883.github.io/Real-A-Who/real-o-who/terms-of-use/"
    const val SUPPORT = "https://roper8883.github.io/Real-A-Who/real-o-who/support/"
    const val MAIL = "mailto:aroper8@hotmail.com"
}

private val entryTimestampFormatter = DateTimeFormatter.ofPattern("EEE, d MMM • h:mm a")

@Composable
fun RealOWhoApp(
    store: ReflectionStore,
    launchConfiguration: AppLaunchConfiguration
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()
    var selectedTabName by rememberSaveable {
        mutableStateOf((launchConfiguration.initialTab ?: AppTab.TODAY).name)
    }
    val selectedTab = AppTab.valueOf(selectedTabName)

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
        bottomBar = {
            NavigationBar {
                AppTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTabName = tab.name },
                        icon = { Text(tab.symbol) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { innerPadding ->
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            color = MaterialTheme.colorScheme.background
        ) {
            when (selectedTab) {
                AppTab.TODAY -> TodayScreen(
                    store = store,
                    onShowMessage = { message ->
                        coroutineScope.launch { snackbarHostState.showSnackbar(message) }
                    }
                )

                AppTab.ENTRIES -> EntriesScreen(
                    store = store,
                    onShowMessage = { message ->
                        coroutineScope.launch { snackbarHostState.showSnackbar(message) }
                    }
                )

                AppTab.INSIGHTS -> InsightsScreen(store = store)
                AppTab.ABOUT -> AboutScreen()
            }
        }
    }
}

@Composable
private fun TodayScreen(
    store: ReflectionStore,
    onShowMessage: (String) -> Unit
) {
    var draftText by rememberSaveable { mutableStateOf("") }
    var tagsText by rememberSaveable { mutableStateOf("") }
    var selectedMoodName by rememberSaveable { mutableStateOf(ReflectionMood.CLEAR.name) }
    var selectedPromptId by rememberSaveable { mutableStateOf(store.todayPrompt.id) }
    val selectedMood = ReflectionMood.valueOf(selectedMoodName)
    val selectedPrompt = store.prompt(selectedPromptId) ?: store.todayPrompt

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            SectionHeading(
                title = "Real O Who",
                subtitle = "A private journal for honest check-ins. No account, no ads, and no analytics."
            )
        }

        item {
            HighlightCard {
                Text(
                    text = "Reflections stay on your device unless you choose to share them.",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(14.dp))
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    MetricChip("Entries", store.entries.size.toString())
                    MetricChip("Favorites", store.favoriteCount.toString())
                    MetricChip("This week", store.entriesThisWeek.toString())
                }
            }
        }

        item {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "Pick a prompt",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(store.prompts, key = { it.id }) { prompt ->
                        PromptCard(
                            prompt = prompt,
                            selected = prompt.id == selectedPromptId,
                            onClick = { selectedPromptId = prompt.id }
                        )
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                shape = RoundedCornerShape(24.dp)
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Text(
                        text = selectedPrompt.title,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = selectedPrompt.guidance,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = draftText,
                        onValueChange = { draftText = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp),
                        placeholder = { Text(selectedPrompt.placeholder) }
                    )
                    Text(
                        text = "Mood",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Medium
                    )
                    MoodSelector(
                        selectedMood = selectedMood,
                        onSelectMood = { selectedMoodName = it.name }
                    )
                    OutlinedTextField(
                        value = tagsText,
                        onValueChange = { tagsText = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Tags") },
                        supportingText = { Text("Separate tags with commas") }
                    )
                    Button(
                        onClick = {
                            val saved = store.addEntry(
                                prompt = selectedPrompt,
                                text = draftText,
                                mood = selectedMood,
                                tagsText = tagsText
                            )
                            if (saved) {
                                draftText = ""
                                tagsText = ""
                                selectedMoodName = ReflectionMood.CLEAR.name
                                selectedPromptId = store.nextPrompt(selectedPromptId).id
                                onShowMessage("Reflection saved on this device.")
                            } else {
                                onShowMessage("Write a little before saving.")
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Save Reflection")
                    }
                }
            }
        }

        item {
            Text(
                text = "Recent entries",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }

        items(store.recentEntries, key = { it.id }) { entry ->
            EntrySummaryCard(
                entry = entry,
                onToggleFavorite = { store.toggleFavorite(entry.id) }
            )
        }
    }
}

@Composable
private fun EntriesScreen(
    store: ReflectionStore,
    onShowMessage: (String) -> Unit
) {
    var query by rememberSaveable { mutableStateOf("") }
    var filterName by rememberSaveable { mutableStateOf(EntryFilter.ALL.name) }
    var editingEntryId by rememberSaveable { mutableStateOf<String?>(null) }
    val filter = EntryFilter.valueOf(filterName)
    val entries = store.filteredEntries(
        query = query,
        favoritesOnly = filter == EntryFilter.FAVORITES
    )
    val editingEntry = editingEntryId?.let(store::entry)

    if (editingEntry != null) {
        EntryEditorDialog(
            entry = editingEntry,
            onDismiss = { editingEntryId = null },
            onSave = { text, mood, tagsText, isFavorite ->
                store.updateEntry(
                    id = editingEntry.id,
                    text = text,
                    mood = mood,
                    tagsText = tagsText,
                    isFavorite = isFavorite
                )
                editingEntryId = null
                onShowMessage("Entry updated.")
            }
        )
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            SectionHeading(
                title = "Entries",
                subtitle = "Search reflections, revisit favorites, and edit anything you have written."
            )
        }

        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Search") },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Outlined.Search,
                        contentDescription = null
                    )
                }
            )
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                EntryFilter.entries.forEach { option ->
                    FilterChip(
                        selected = filter == option,
                        onClick = { filterName = option.name },
                        label = { Text(option.title) }
                    )
                }
            }
        }

        if (entries.isEmpty()) {
            item {
                EmptyStateCard("No reflections match that search yet.")
            }
        } else {
            items(entries, key = { it.id }) { entry ->
                EditableEntryCard(
                    entry = entry,
                    onClick = { editingEntryId = entry.id },
                    onToggleFavorite = { store.toggleFavorite(entry.id) },
                    onDelete = {
                        store.deleteEntry(entry.id)
                        if (editingEntryId == entry.id) {
                            editingEntryId = null
                        }
                        onShowMessage("Entry deleted.")
                    }
                )
            }
        }
    }
}

@Composable
@OptIn(ExperimentalLayoutApi::class)
private fun InsightsScreen(store: ReflectionStore) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            SectionHeading(
                title = "Insights",
                subtitle = "Simple patterns calculated on-device from your saved reflections."
            )
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Entries",
                    value = store.entries.size.toString()
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Words",
                    value = store.totalWordCount.toString()
                )
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Average",
                    value = store.averageWordCount.toString()
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Streak",
                    value = "${store.streakDays}d"
                )
            }
        }

        item {
            Card(
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        text = "Most common mood",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = store.mostCommonMood?.let { "${it.symbol} ${it.title}" } ?: "No entries yet",
                        style = MaterialTheme.typography.headlineSmall
                    )
                }
            }
        }

        item {
            Card(
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "Top tags",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )

                    if (store.topTags.isEmpty()) {
                        Text(
                            text = "Start adding tags to see your recurring themes.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    } else {
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            store.topTags.take(8).forEach { tag ->
                                AssistChip(
                                    onClick = { },
                                    label = { Text("${tag.tag} (${tag.count})") }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AboutScreen() {
    val context = androidx.compose.ui.platform.LocalContext.current

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            SectionHeading(
                title = "About",
                subtitle = "Real O Who is a quiet, offline journal with no account system and no analytics."
            )
        }

        item {
            HighlightCard {
                Text(
                    text = "Everything stays on your device unless you choose to open a support or legal link.",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        item {
            LinkCard(
                title = "Website",
                subtitle = "Public app page",
                icon = {
                    Icon(
                        imageVector = Icons.Outlined.Public,
                        contentDescription = null
                    )
                },
                onClick = { openExternalLink(context, LegalLinks.HOME) }
            )
        }

        item {
            LinkCard(
                title = "Privacy Policy",
                subtitle = "How the app handles data",
                icon = {
                    Icon(
                        imageVector = Icons.Outlined.Policy,
                        contentDescription = null
                    )
                },
                onClick = { openExternalLink(context, LegalLinks.PRIVACY) }
            )
        }

        item {
            LinkCard(
                title = "Terms of Use",
                subtitle = "Standard usage terms",
                icon = {
                    Icon(
                        imageVector = Icons.Outlined.Description,
                        contentDescription = null
                    )
                },
                onClick = { openExternalLink(context, LegalLinks.TERMS) }
            )
        }

        item {
            LinkCard(
                title = "Support",
                subtitle = "Help and contact page",
                icon = {
                    Icon(
                        imageVector = Icons.Outlined.Public,
                        contentDescription = null
                    )
                },
                onClick = { openExternalLink(context, LegalLinks.SUPPORT) }
            )
        }

        item {
            LinkCard(
                title = "Email Support",
                subtitle = "aroper8@hotmail.com",
                icon = {
                    Icon(
                        imageVector = Icons.Outlined.Email,
                        contentDescription = null
                    )
                },
                onClick = { openExternalLink(context, LegalLinks.MAIL) }
            )
        }
    }
}

@Composable
private fun SectionHeading(
    title: String,
    subtitle: String
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = subtitle,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun HighlightCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content
        )
    }
}

@Composable
private fun MetricChip(
    title: String,
    value: String
) {
    Column(
        modifier = Modifier
            .background(
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                shape = RoundedCornerShape(20.dp)
            )
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = title,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PromptCard(
    prompt: ReflectionPrompt,
    selected: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .width(280.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (selected) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.surface
            }
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = prompt.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = prompt.guidance,
                color = if (selected) {
                    MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.9f)
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

@Composable
@OptIn(ExperimentalLayoutApi::class)
private fun MoodSelector(
    selectedMood: ReflectionMood,
    onSelectMood: (ReflectionMood) -> Unit
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ReflectionMood.entries.forEach { mood ->
            FilterChip(
                selected = selectedMood == mood,
                onClick = { onSelectMood(mood) },
                label = { Text("${mood.symbol} ${mood.title}") }
            )
        }
    }
}

@Composable
private fun EntrySummaryCard(
    entry: ReflectionEntry,
    onToggleFavorite: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = entry.promptTitle,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = formatTimestamp(entry.updatedAt),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onToggleFavorite) {
                    Icon(
                        imageVector = if (entry.isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = null,
                        tint = if (entry.isFavorite) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Text(
                text = entry.previewText,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = buildMetaText(entry),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun EditableEntryCard(
    entry: ReflectionEntry,
    onClick: () -> Unit,
    onToggleFavorite: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = entry.promptTitle,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = formatTimestamp(entry.updatedAt),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onToggleFavorite) {
                    Icon(
                        imageVector = if (entry.isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = null,
                        tint = if (entry.isFavorite) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onDelete) {
                    Icon(
                        imageVector = Icons.Outlined.Delete,
                        contentDescription = null
                    )
                }
            }
            Text(
                text = entry.previewText,
                maxLines = 4,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = buildMetaText(entry),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun EntryEditorDialog(
    entry: ReflectionEntry,
    onDismiss: () -> Unit,
    onSave: (String, ReflectionMood, String, Boolean) -> Unit
) {
    var text by rememberSaveable(entry.id) { mutableStateOf(entry.text) }
    var tagsText by rememberSaveable(entry.id) { mutableStateOf(entry.tags.joinToString(", ")) }
    var favorite by rememberSaveable(entry.id) { mutableStateOf(entry.isFavorite) }
    var moodName by rememberSaveable(entry.id) { mutableStateOf(entry.mood.name) }
    val mood = ReflectionMood.valueOf(moodName)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Edit Entry",
                fontWeight = FontWeight.SemiBold
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = entry.promptTitle,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                )
                MoodSelector(
                    selectedMood = mood,
                    onSelectMood = { moodName = it.name }
                )
                OutlinedTextField(
                    value = tagsText,
                    onValueChange = { tagsText = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Tags") }
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("Favorite")
                    Switch(checked = favorite, onCheckedChange = { favorite = it })
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(text, mood, tagsText, favorite) }
            ) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
private fun EmptyStateCard(message: String) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Text(
            text = message,
            modifier = Modifier.padding(18.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun StatCard(
    modifier: Modifier = Modifier,
    title: String,
    value: String
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = title,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun LinkCard(
    title: String,
    subtitle: String,
    icon: @Composable () -> Unit,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier
                    .background(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(16.dp)
                    )
                    .padding(12.dp)
            ) {
                icon()
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = subtitle,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = "Open",
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

private fun buildMetaText(entry: ReflectionEntry): String {
    val tags = if (entry.tags.isEmpty()) "" else " • ${entry.tags.joinToString(", ")}"
    return "${entry.mood.symbol} ${entry.mood.title} • ${entry.wordCount} words$tags"
}

private fun formatTimestamp(epochMillis: Long): String {
    return entryTimestampFormatter.format(
        Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault())
    )
}

private fun openExternalLink(
    context: Context,
    target: String
) {
    val intent = if (target.startsWith("mailto:")) {
        Intent(Intent.ACTION_SENDTO, Uri.parse(target))
    } else {
        Intent(Intent.ACTION_VIEW, Uri.parse(target))
    }.apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
    }
}
