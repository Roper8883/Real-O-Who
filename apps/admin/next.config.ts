import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@homeowner/domain", "@homeowner/types", "@homeowner/ui"],
};

export default nextConfig;
