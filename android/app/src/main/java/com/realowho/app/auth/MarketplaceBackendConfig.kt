package com.realowho.app.auth

import com.realowho.app.AppLaunchConfiguration

enum class MarketplaceRemoteMode {
    LOCAL_ONLY,
    REMOTE_PREFERRED
}

data class MarketplaceBackendConfig(
    val mode: MarketplaceRemoteMode,
    val baseUrl: String?,
    val timeoutSeconds: Long = 4
) {
    companion object {
        fun launchDefault(launchConfiguration: AppLaunchConfiguration): MarketplaceBackendConfig {
            if (launchConfiguration.isScreenshotMode) {
                return MarketplaceBackendConfig(
                    mode = MarketplaceRemoteMode.LOCAL_ONLY,
                    baseUrl = null
                )
            }

            val environmentUrl = System.getenv("REAL_O_WHO_API_BASE_URL")
            if (!environmentUrl.isNullOrBlank()) {
                return MarketplaceBackendConfig(
                    mode = MarketplaceRemoteMode.REMOTE_PREFERRED,
                    baseUrl = environmentUrl
                )
            }

            return MarketplaceBackendConfig(
                mode = MarketplaceRemoteMode.REMOTE_PREFERRED,
                baseUrl = "http://10.0.2.2:8080"
            )
        }
    }
}
