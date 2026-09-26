import ProductHuntStatus from "./components/ProductHuntStatus";

const install = `name: PR Conductor

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  conduct:
    uses: DeontewattsV1/PR-Conductor/.github/workflows/reusable.yml@v2
    with:
      pr_number: ${{ github.event.pull_request.number || 0 }}`;

export default function Home() {
  return (
    <main>
      <nav className="nav shell">
        <a className="brand" href="#top" aria-label="PR Conductor home">
          <span className="brandMark">PR</span>
          <span>Conductor</span>
        </a>
        <div className="navLinks">
          <a href="#how">How it works</a>
          <a href="#install">Install</a>
          <a
            href="https://github.com/DeontewattsV1/PR-Conductor"
            target="_blank"
            rel="noreferrer"
          >
            GitHub
          </a>
        </div>
      </nav>

      <section id="top" className="hero shell">
        <div className="eyebrow">GitHub pull request control plane · v2</div>
        <h1>PRs arrive ready to review.</h1>
        <p className="lede">
          Move repetitive pull request preparation upstream. PR Conductor
          normalizes metadata, keeps branches current, respects repository
          policy, coordinates merge strategy, and supports GitHub stacked pull
          requests without bypassing protections.
        </p>
        <div className="actions">
          <a className="button primary" href="#install">
            Install PR Conductor
          </a>
          <a
            className="button secondary"
            href="https://github.com/DeontewattsV1/PR-Conductor"
            target="_blank"
            rel="noreferrer"
          >
            View source
          </a>
        </div>
        <div className="signalGrid" aria-label="PR Conductor capabilities">
          <div><strong>Validate</strong><span>metadata + repository state</span></div>
          <div><strong>Prepare</strong><span>titles + branch freshness</span></div>
          <div><strong>Policy</strong><span>labels + protections + queues</span></div>
          <div><strong>Review</strong><span>one compact status surface</span></div>
        </div>
      </section>

      <section id="how" className="section shell">
        <div className="sectionHeader">
          <span>Control flow</span>
          <h2>Review code, not process.</h2>
        </div>
        <div className="pipeline">
          {["Open", "Validate", "Analyze", "Prepare", "Policy check", "Review ready"].map(
            (step, index) => (
              <div className="step" key={step}>
                <span>{String(index + 1).padStart(2, "0")}</span>
                <strong>{step}</strong>
              </div>
            )
          )}
        </div>
      </section>

      <section className="section shell split">
        <div>
          <div className="sectionHeader">
            <span>Product Hunt connection</span>
            <h2>PKCE, no client secret.</h2>
          </div>
          <p className="muted">
            The launch companion uses Product Hunt&apos;s public-client OAuth flow
            with PKCE. Access tokens stay out of source control and are stored
            only in an encrypted, HTTP-only session cookie.
          </p>
        </div>
        <ProductHuntStatus />
      </section>

      <section id="install" className="section shell">
        <div className="sectionHeader">
          <span>Fastest installation</span>
          <h2>One reusable workflow call.</h2>
        </div>
        <pre className="code"><code>{install}</code></pre>
        <p className="muted">
          Pin production repositories to an immutable release tag or commit SHA
          when stronger supply-chain guarantees are required.
        </p>
      </section>

      <footer className="footer shell">
        <span>PR Conductor</span>
        <span>Good people. Good systems in motion.</span>
      </footer>
    </main>
  );
}
