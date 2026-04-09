# Real O Who Backend

This is a lightweight local development backend for `Real O Who`. It gives the native apps a working API for:

- shared listing inventory
- account creation
- sign in
- saved homes and saved searches
- conversation sync for direct messaging
- legal professional search
- shared sale coordination sync

## Run

```sh
cd backend
npm start
```

The service listens on `http://127.0.0.1:8080` by default and stores data in `backend/data/dev-server.json`.

## Demo Accounts

The backend ensures two seeded accounts are always available for local testing:

- Buyer: `noah@realowho.app`
- Seller: `mason@realowho.app`
- Shared password: `HouseDeal123!`

Those accounts share a seeded New Farm listing and sale so the browse, saved-state, legal-selection, contract, and messaging flow is ready as soon as the apps connect.

## Endpoints

- `GET /health`
- `POST /v1/auth/sign-up`
- `POST /v1/auth/sign-in`
- `GET /v1/conversations?userId=<uuid>`
- `PUT /v1/conversations/<conversation-id>`
- `GET /v1/marketplace-state/<user-id>`
- `PUT /v1/marketplace-state/<user-id>`
- `GET /v1/listings`
- `GET /v1/listings/<listing-id>`
- `PUT /v1/listings/<listing-id>`
- `GET /v1/legal-professionals/search`
- `GET /v1/sales?userId=<uuid>`
- `GET /v1/sales/by-listing/<listing-id>`
- `PUT /v1/sales/by-listing/<listing-id>`
