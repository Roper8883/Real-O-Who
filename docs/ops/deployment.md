# Deployment

## Environment model

- local: Docker Compose with Postgres, Redis, and MinIO
- staging: production-like integrations with lower-risk credentials
- production: managed PostgreSQL, Redis, object storage, CDN, and observability stack

## Recommended production topology

- web and admin on Vercel or equivalent edge-friendly host
- API on Fly, Render, ECS, or Kubernetes
- Postgres on RDS, Neon, Supabase, or equivalent managed service
- Redis on Upstash or managed Redis
- object storage on S3-compatible provider

## Release flow

1. branch build and PR checks
2. staging deploy
3. smoke tests
4. production deploy
5. post-deploy verification
