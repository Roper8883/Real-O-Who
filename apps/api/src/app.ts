import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import Fastify from "fastify";
import { registerRoutes } from "./routes/index.js";

export async function buildApp() {
  const app = Fastify({
    logger: false,
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
    },
  });

  await app.register(swaggerUi, {
    routePrefix: "/docs",
  });

  await registerRoutes(app);

  return app;
}
