import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import Fastify from "fastify";
import { buildPublicRuntimeConfig, loadEnv } from "@homeowner/config";
import { buildProviderRegistry } from "@homeowner/integrations";
import { registerRoutes } from "./routes/index";
import { logger } from "./lib/logger";

export async function buildApp() {
  const env = loadEnv();
  const publicConfig = buildPublicRuntimeConfig();
  const providers = buildProviderRegistry();

  const app = Fastify({
    logger: env.NODE_ENV !== "test",
  });

  await app.register(cors, {
    origin: true,
  });

  await app.register(swagger, {
    openapi: {
      info: {
        title: "Homeowner API",
        version: "0.1.0",
        description:
          "Private property sale platform API for Australia-first owner-to-buyer residential sales.",
      },
      servers: [{ url: env.API_URL }],
    },
  });

  await app.register(swaggerUi, {
    routePrefix: "/docs",
  });

  app.decorate("envConfig", env);
  app.decorate("publicConfig", publicConfig);
  app.decorate("providers", providers);

  app.setErrorHandler((error, request, reply) => {
    const message = error instanceof Error ? error.message : "Unknown error";

    logger.error({
      message: "Unhandled API error",
      requestId: request.id,
      method: request.method,
      url: request.url,
      error: message,
    });

    reply.status(500).send({
      message: "Unexpected server error",
      requestId: request.id,
    });
  });

  await registerRoutes(app);

  return app;
}
