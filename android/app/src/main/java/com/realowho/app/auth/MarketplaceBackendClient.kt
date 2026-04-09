package com.realowho.app.auth

import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

class MarketplaceRemoteException(
    val canFallback: Boolean,
    override val message: String
) : Exception(message)

@Serializable
internal data class MarketplaceErrorEnvelope(
    val error: String? = null
)

class MarketplaceBackendClient(
    private val config: MarketplaceBackendConfig,
    private val json: Json = Json {
        ignoreUnknownKeys = true
        prettyPrint = true
    }
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(config.timeoutSeconds, TimeUnit.SECONDS)
        .readTimeout(config.timeoutSeconds, TimeUnit.SECONDS)
        .writeTimeout(config.timeoutSeconds, TimeUnit.SECONDS)
        .build()

    internal suspend inline fun <reified Response> get(
        path: String,
        queryParameters: Map<String, String> = emptyMap()
    ): Response = withContext(Dispatchers.IO) {
        val urlBuilder = config.baseUrl
            ?.toHttpUrlOrNull()
            ?.newBuilder()
            ?: throw MarketplaceRemoteException(
                canFallback = true,
                message = "The marketplace backend URL is not configured."
            )

        path.split("/").filter { it.isNotBlank() }.forEach(urlBuilder::addPathSegment)
        queryParameters.forEach { (key, value) -> urlBuilder.addQueryParameter(key, value) }

        val request = Request.Builder()
            .url(urlBuilder.build())
            .get()
            .build()

        execute(request)
    }

    internal suspend inline fun <reified Body, reified Response> post(
        path: String,
        body: Body
    ): Response = requestWithBody(path = path, method = "POST", body = body)

    internal suspend inline fun <reified Body, reified Response> requestWithBody(
        path: String,
        method: String,
        body: Body
    ): Response = withContext(Dispatchers.IO) {
        val urlBuilder = config.baseUrl
            ?.toHttpUrlOrNull()
            ?.newBuilder()
            ?: throw MarketplaceRemoteException(
                canFallback = true,
                message = "The marketplace backend URL is not configured."
            )

        path.split("/").filter { it.isNotBlank() }.forEach(urlBuilder::addPathSegment)

        val request = Request.Builder()
            .url(urlBuilder.build())
            .method(
                method,
                json.encodeToString(body).toRequestBody("application/json".toMediaType())
            )
            .build()

        execute(request)
    }

    internal suspend inline fun <reified Response> execute(request: Request): Response = withContext(Dispatchers.IO) {
        try {
            client.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    val message = runCatching {
                        json.decodeFromString<MarketplaceErrorEnvelope>(body).error
                    }.getOrNull() ?: "Backend request failed."

                    throw MarketplaceRemoteException(
                        canFallback = false,
                        message = message
                    )
                }

                json.decodeFromString(body)
            }
        } catch (error: MarketplaceRemoteException) {
            throw error
        } catch (error: IOException) {
            throw MarketplaceRemoteException(
                canFallback = true,
                message = error.localizedMessage ?: "The marketplace backend is unavailable right now."
            )
        }
    }
}
