package com.realowho.app.data

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.model.ReflectionEntry
import com.realowho.app.model.ReflectionMood
import com.realowho.app.model.ReflectionPrompt
import com.realowho.app.model.ReflectionSeed
import com.realowho.app.model.TagInsight
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class ReflectionStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration
) {
    private val entriesState = mutableStateListOf<ReflectionEntry>()
    private val promptsInternal = ReflectionPrompt.defaults
    private val storageFile = File(
        File(context.filesDir, "real-o-who-journal"),
        "reflections.json"
    )
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val isEphemeral = launchConfiguration.isScreenshotMode

    val prompts: List<ReflectionPrompt>
        get() = promptsInternal

    val entries: List<ReflectionEntry>
        get() = entriesState

    init {
        if (isEphemeral) {
            entriesState.addAll(ReflectionSeed.screenshotEntries())
        } else {
            load()
        }
    }

    val todayPrompt: ReflectionPrompt
        get() {
            if (isEphemeral) {
                return promptsInternal.first()
            }

            val dayOfYear = LocalDate.now().dayOfYear
            return promptsInternal[dayOfYear % promptsInternal.size]
        }

    val recentEntries: List<ReflectionEntry>
        get() = entries.take(3)

    val favoriteCount: Int
        get() = entries.count { it.isFavorite }

    val entriesThisWeek: Int
        get() {
            val zoneId = ZoneId.systemDefault()
            val today = LocalDate.now(zoneId)
            val firstDayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek
            val weekStart = today.with(TemporalAdjusters.previousOrSame(firstDayOfWeek))

            return entries.count { entry ->
                val entryDate = Instant.ofEpochMilli(entry.createdAt).atZone(zoneId).toLocalDate()
                !entryDate.isBefore(weekStart)
            }
        }

    val totalWordCount: Int
        get() = entries.sumOf { it.wordCount }

    val averageWordCount: Int
        get() = if (entries.isEmpty()) 0 else totalWordCount / entries.size

    val streakDays: Int
        get() {
            if (entries.isEmpty()) {
                return 0
            }

            val zoneId = ZoneId.systemDefault()
            val uniqueDays = entries
                .map { Instant.ofEpochMilli(it.createdAt).atZone(zoneId).toLocalDate() }
                .toSet()

            var streak = 0
            var cursor = LocalDate.now(zoneId)

            while (uniqueDays.contains(cursor)) {
                streak += 1
                cursor = cursor.minusDays(1)
            }

            return streak
        }

    val mostCommonMood: ReflectionMood?
        get() = entries
            .groupingBy { it.mood }
            .eachCount()
            .entries
            .sortedWith(
                compareByDescending<Map.Entry<ReflectionMood, Int>> { it.value }
                    .thenBy { it.key.title }
            )
            .firstOrNull()
            ?.key

    val topTags: List<TagInsight>
        get() = entries
            .flatMap { it.tags }
            .groupingBy { it }
            .eachCount()
            .map { TagInsight(tag = it.key, count = it.value) }
            .sortedWith(compareByDescending<TagInsight> { it.count }.thenBy { it.tag })

    fun prompt(id: String?): ReflectionPrompt? = promptsInternal.firstOrNull { it.id == id }

    fun nextPrompt(after: String?): ReflectionPrompt {
        val index = promptsInternal.indexOfFirst { it.id == after }
        return if (index == -1) {
            todayPrompt
        } else {
            promptsInternal[(index + 1) % promptsInternal.size]
        }
    }

    fun entry(id: String): ReflectionEntry? = entries.firstOrNull { it.id == id }

    fun filteredEntries(query: String, favoritesOnly: Boolean): List<ReflectionEntry> {
        val normalizedQuery = query.trim().lowercase(Locale.getDefault())

        return entries.filter { entry ->
            val matchesFavorites = !favoritesOnly || entry.isFavorite
            if (!matchesFavorites) {
                return@filter false
            }

            if (normalizedQuery.isBlank()) {
                return@filter true
            }

            val haystack = buildString {
                append(entry.promptTitle)
                append(' ')
                append(entry.text)
                append(' ')
                append(entry.mood.title)
                append(' ')
                append(entry.tags.joinToString(" "))
            }.lowercase(Locale.getDefault())

            haystack.contains(normalizedQuery)
        }
    }

    fun addEntry(
        prompt: ReflectionPrompt,
        text: String,
        mood: ReflectionMood,
        tagsText: String
    ): Boolean {
        val body = sanitizeText(text)
        if (body.isBlank()) {
            return false
        }

        val now = System.currentTimeMillis()
        entriesState.add(
            0,
            ReflectionEntry(
                id = UUID.randomUUID().toString(),
                promptTitle = prompt.title,
                text = body,
                mood = mood,
                tags = parseTags(tagsText),
                createdAt = now,
                updatedAt = now,
                isFavorite = false
            )
        )
        persist()
        return true
    }

    fun updateEntry(
        id: String,
        text: String,
        mood: ReflectionMood,
        tagsText: String,
        isFavorite: Boolean
    ) {
        val index = entriesState.indexOfFirst { it.id == id }
        if (index == -1) {
            return
        }

        val body = sanitizeText(text)
        if (body.isBlank()) {
            return
        }

        val current = entriesState[index]
        entriesState[index] = current.copy(
            text = body,
            mood = mood,
            tags = parseTags(tagsText),
            isFavorite = isFavorite,
            updatedAt = System.currentTimeMillis()
        )
        sortEntries()
        persist()
    }

    fun toggleFavorite(id: String) {
        val index = entriesState.indexOfFirst { it.id == id }
        if (index == -1) {
            return
        }

        val current = entriesState[index]
        entriesState[index] = current.copy(
            isFavorite = !current.isFavorite,
            updatedAt = System.currentTimeMillis()
        )
        sortEntries()
        persist()
    }

    fun deleteEntry(id: String) {
        val removed = entriesState.removeAll { it.id == id }
        if (removed) {
            persist()
        }
    }

    private fun sanitizeText(text: String): String {
        return text
            .trim()
            .lineSequence()
            .map { it.trim() }
            .joinToString("\n")
            .trim()
    }

    private fun parseTags(tagsText: String): List<String> {
        return tagsText
            .split(',')
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
    }

    private fun sortEntries() {
        val sorted = entriesState.sortedByDescending { it.updatedAt }
        entriesState.clear()
        entriesState.addAll(sorted)
    }

    private fun load() {
        runCatching {
            storageFile.parentFile?.mkdirs()
            if (!storageFile.exists()) {
                return
            }

            val snapshot = json.decodeFromString<ReflectionSnapshot>(storageFile.readText())
            entriesState.clear()
            entriesState.addAll(snapshot.entries.sortedByDescending { it.updatedAt })
        }
    }

    private fun persist() {
        if (isEphemeral) {
            return
        }

        runCatching {
            storageFile.parentFile?.mkdirs()
            val snapshot = ReflectionSnapshot(entries = entriesState.toList())
            storageFile.writeText(json.encodeToString(snapshot))
        }
    }
}

@Serializable
private data class ReflectionSnapshot(
    val entries: List<ReflectionEntry>
)
