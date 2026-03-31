# Media Pipeline

## Supported asset types

- photography
- video
- floorplans
- site plans
- brochures
- seller-provided reports and disclosure documents

## Processing stages

1. secure upload signing
2. virus/prohibited-content scan hook
3. EXIF stripping
4. responsive image generation
5. optional watermarking
6. video transcode and poster generation
7. metadata persistence and access-policy assignment

## Security and UX requirements

- signed read URLs for private documents
- role-based access rules
- alt text and caption support
- progressive loading for gallery assets
- expiry tracking for stale legal or inspection documents
