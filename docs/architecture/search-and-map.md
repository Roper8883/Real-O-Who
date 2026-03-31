# Search and Map

## Search principles

- preserve filters in URLs
- keep interactions fast on mobile networks
- support map/list sync and future polygon search
- degrade gracefully when enrichment data is missing

## V1 implementation

- shared filter serialization and parsing lives in `packages/search`
- listing filtering uses first-party listing data
- the UI is map-adapter ready but can ship with list-first mode while integrations are finalised

## Future upgrades

- OpenSearch or Elasticsearch adapter
- suburb landing pages and SEO facets
- map clustering service
- draw-on-map polygon persistence and saved map searches
