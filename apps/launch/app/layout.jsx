import "./globals.css";

export const metadata = {
  title: "PR Conductor — PRs arrive ready to review",
  description:
    "Policy-driven GitHub pull request automation for review readiness, merge strategy, stacks, and protected delivery."
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
