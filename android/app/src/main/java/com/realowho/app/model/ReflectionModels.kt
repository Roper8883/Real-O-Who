package com.realowho.app.model

import kotlinx.serialization.Serializable

@Serializable
enum class ReflectionMood(
    val title: String,
    val symbol: String
) {
    CLEAR("Clear", "☀️"),
    GRATEFUL("Grateful", "❤️"),
    GROUNDED("Grounded", "🌿"),
    CURIOUS("Curious", "✨"),
    HONEST("Honest", "✔️"),
    HOPEFUL("Hopeful", "🌙")
}

@Serializable
data class ReflectionPrompt(
    val id: String,
    val title: String,
    val guidance: String,
    val placeholder: String
) {
    companion object {
        val defaults = listOf(
            ReflectionPrompt(
                id = "prompt-what-felt-true",
                title = "What felt true today?",
                guidance = "Write about one moment that felt honest, simple, or unexpectedly important.",
                placeholder = "I felt most like myself when..."
            ),
            ReflectionPrompt(
                id = "prompt-carrying",
                title = "What are you carrying right now?",
                guidance = "Name the pressure, emotion, or thought that keeps returning today.",
                placeholder = "The thing I keep circling back to is..."
            ),
            ReflectionPrompt(
                id = "prompt-attention",
                title = "What deserves more attention?",
                guidance = "Think about a relationship, task, habit, or idea that you do not want to ignore.",
                placeholder = "I want to give more attention to..."
            ),
            ReflectionPrompt(
                id = "prompt-let-go",
                title = "What can you let go of?",
                guidance = "Describe one expectation, worry, or story that can be softened today.",
                placeholder = "I can loosen my grip on..."
            ),
            ReflectionPrompt(
                id = "prompt-tomorrow",
                title = "What do you want tomorrow to feel like?",
                guidance = "Use a few sentences to set a tone instead of a perfect plan.",
                placeholder = "Tomorrow I want to feel..."
            ),
            ReflectionPrompt(
                id = "prompt-proud",
                title = "What are you quietly proud of?",
                guidance = "Capture one thing you handled well, even if nobody else noticed.",
                placeholder = "I am proud that I..."
            )
        )
    }
}

@Serializable
data class ReflectionEntry(
    val id: String,
    val promptTitle: String,
    val text: String,
    val mood: ReflectionMood,
    val tags: List<String>,
    val createdAt: Long,
    val updatedAt: Long,
    val isFavorite: Boolean
) {
    val previewText: String
        get() = text.replace('\n', ' ').trim()

    val wordCount: Int
        get() = text.split(Regex("\\s+")).filter { it.isNotBlank() }.size
}

data class TagInsight(
    val tag: String,
    val count: Int
)

object ReflectionSeed {
    fun screenshotEntries(nowMillis: Long = System.currentTimeMillis()): List<ReflectionEntry> {
        val dayMillis = 24L * 60L * 60L * 1000L

        fun at(daysAgo: Int, offsetHours: Int, offsetMinutes: Int): Long {
            return nowMillis -
                (daysAgo * dayMillis) -
                (offsetHours * 60L * 60L * 1000L) -
                (offsetMinutes * 60L * 1000L)
        }

        return listOf(
            ReflectionEntry(
                id = "entry-1",
                promptTitle = ReflectionPrompt.defaults[0].title,
                text = "I felt most like myself when I slowed down enough to finish one thing well instead of chasing five half-finished tasks.",
                mood = ReflectionMood.CLEAR,
                tags = listOf("Focus", "Work"),
                createdAt = at(daysAgo = 0, offsetHours = 2, offsetMinutes = 15),
                updatedAt = at(daysAgo = 0, offsetHours = 2, offsetMinutes = 8),
                isFavorite = true
            ),
            ReflectionEntry(
                id = "entry-2",
                promptTitle = ReflectionPrompt.defaults[1].title,
                text = "The thing I keep circling back to is how much lighter I feel when I stop performing certainty and just admit what I need.",
                mood = ReflectionMood.HONEST,
                tags = listOf("Energy", "Self-trust"),
                createdAt = at(daysAgo = 1, offsetHours = 6, offsetMinutes = 10),
                updatedAt = at(daysAgo = 1, offsetHours = 5, offsetMinutes = 52),
                isFavorite = false
            ),
            ReflectionEntry(
                id = "entry-3",
                promptTitle = ReflectionPrompt.defaults[2].title,
                text = "I want to give more attention to mornings that start without my phone. The day feels calmer when I begin with intention.",
                mood = ReflectionMood.GROUNDED,
                tags = listOf("Routine", "Energy"),
                createdAt = at(daysAgo = 2, offsetHours = 1, offsetMinutes = 30),
                updatedAt = at(daysAgo = 2, offsetHours = 1, offsetMinutes = 18),
                isFavorite = true
            ),
            ReflectionEntry(
                id = "entry-4",
                promptTitle = ReflectionPrompt.defaults[4].title,
                text = "Tomorrow I want to feel steadier, less reactive, and more present in the conversations that actually matter.",
                mood = ReflectionMood.HOPEFUL,
                tags = listOf("Family", "Presence"),
                createdAt = at(daysAgo = 3, offsetHours = 11, offsetMinutes = 10),
                updatedAt = at(daysAgo = 3, offsetHours = 11, offsetMinutes = 2),
                isFavorite = false
            ),
            ReflectionEntry(
                id = "entry-5",
                promptTitle = ReflectionPrompt.defaults[5].title,
                text = "I am proud that I protected a quiet hour for myself instead of giving every spare minute away.",
                mood = ReflectionMood.GRATEFUL,
                tags = listOf("Rest", "Self-trust"),
                createdAt = at(daysAgo = 4, offsetHours = 8, offsetMinutes = 45),
                updatedAt = at(daysAgo = 4, offsetHours = 8, offsetMinutes = 38),
                isFavorite = false
            )
        )
    }
}

