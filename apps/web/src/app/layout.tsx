import type { Metadata } from "next";
import { Fraunces, Manrope } from "next/font/google";
import "./globals.css";

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-manrope",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-fraunces",
});

export const metadata: Metadata = {
  title: "Homeowner | Private property sale in Australia",
  description:
    "Australia-first private property sale platform for homeowners, buyers, inspectors, and compliance teams.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en-AU"
      className={`${manrope.variable} ${fraunces.variable} min-h-full antialiased`}
    >
      <body className="min-h-full">{children}</body>
    </html>
  );
}
