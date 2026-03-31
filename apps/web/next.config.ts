import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: [
    "@homeowner/domain",
    "@homeowner/search",
    "@homeowner/types",
    "@homeowner/ui",
  ],
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "images.unsplash.com",
      },
      {
        protocol: "https",
        hostname: "example.com",
      },
    ],
  },
};

export default nextConfig;
