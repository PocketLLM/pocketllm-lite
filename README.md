# PocketLLM Lite marketing website redesign

This package is designed to drop into the existing `PocketLLM/pocketllm-lite` repository without changing the current static-site deployment model.

## Important: keep your existing logo

The repository already contains the real PocketLLM logo at:

`pocketllm-website/assets/logo.png`

That binary logo is intentionally **not replaced** by this package. Keep it exactly where it is. Every new page references that existing file.

## Replace these existing files

Copy these files from this package over the files in the repository:

- `/index.html`
- `/pocketllm-website/styles.css`
- `/pocketllm-website/privacy.html`
- `/pocketllm-website/terms.html`

## Add these new files

- `/404.html`
- `/pocketllm-website/site.js`
- `/pocketllm-website/releases.html`
- `/pocketllm-website/changelog.html`
- `/pocketllm-website/docs.html`
- `/pocketllm-website/assets/hero-local-ai.webp`
- `/pocketllm-website/assets/workspace-sunrise.webp`
- `/pocketllm-website/assets/runtime-journey.webp`
- `/pocketllm-website/assets/cloud-transition.webp`
- `/pocketllm-website/assets/developer-night.webp`
- `/pocketllm-website/assets/footer-night.webp`
- `/pocketllm-website/assets/feature-collage.webp`

## Recommended repository tree after replacement

```text
pocketllm-lite/
├─ index.html                         ← replace
├─ 404.html                           ← add
├─ pocketllm-website/
│  ├─ styles.css                      ← replace
│  ├─ site.js                         ← add
│  ├─ releases.html                   ← add
│  ├─ changelog.html                  ← add
│  ├─ docs.html                       ← add
│  ├─ privacy.html                    ← replace
│  ├─ terms.html                      ← replace
│  └─ assets/
│     ├─ logo.png                     ← KEEP your existing real logo
│     ├─ hero-local-ai.webp           ← add
│     ├─ workspace-sunrise.webp       ← add
│     ├─ runtime-journey.webp         ← add
│     ├─ cloud-transition.webp        ← add
│     ├─ developer-night.webp         ← add
│     ├─ footer-night.webp            ← add
│     └─ feature-collage.webp         ← add
```

## Fastest replacement workflow

From a clone of the repository, copy the package contents over the repository root. Do **not** delete `pocketllm-website/assets/logo.png` first.

Example on macOS/Linux/Git Bash:

```bash
cp /path/to/pocketllm-marketing-redesign/index.html ./index.html
cp /path/to/pocketllm-marketing-redesign/404.html ./404.html
cp /path/to/pocketllm-marketing-redesign/pocketllm-website/styles.css ./pocketllm-website/styles.css
cp /path/to/pocketllm-marketing-redesign/pocketllm-website/site.js ./pocketllm-website/site.js
cp /path/to/pocketllm-marketing-redesign/pocketllm-website/*.html ./pocketllm-website/
cp /path/to/pocketllm-marketing-redesign/pocketllm-website/assets/*.webp ./pocketllm-website/assets/
```

On Windows, simply copy the same files through Explorer and choose **Replace** for `index.html`, `styles.css`, `privacy.html`, and `terms.html`.

## Preview locally

Do not test the site by double-clicking `index.html` if you want the GitHub release API behavior to match deployment. Run a tiny local HTTP server from the repository root:

```bash
python -m http.server 8080
```

Then open:

`http://localhost:8080/`

Check these widths in DevTools:

- 390px mobile
- 768px tablet
- 1024px laptop
- 1440px desktop
- 1920px wide desktop

## What is dynamic

`site.js` loads public releases from:

`https://api.github.com/repos/PocketLLM/pocketllm-lite/releases?per_page=100`

This powers:

- latest version label on the homepage
- direct latest Android CTA when a universal APK exists
- all release cards on `releases.html`
- old APK download links
- checksums and file sizes when GitHub supplies them
- the complete searchable changelog timeline

If GitHub is temporarily unavailable or rate-limited, the JavaScript has an embedded fallback for v1.0.38, v1.0.37 and v1.0.35 so the pages do not become blank.

## Fonts

The design uses:

- **Instrument Serif** for editorial display headings
- **Manrope** for navigation, UI and body copy
- **Caveat** only for small handwritten section labels

They are currently loaded from Google Fonts. If you later want the marketing site to make zero third-party font requests, self-host properly licensed copies and change the `@font-face` / link setup. Do not commit random downloaded font files without checking their license.

## Image strategy

The generated artwork is intentionally stored as optimized WebP instead of huge PNG source files. Each deployed image is roughly 85–260 KB while retaining enough resolution for large desktop sections.

The pages use native lazy loading for below-the-fold art. The hero is a CSS background and therefore loads immediately.

## Release accuracy

The website deliberately does **not** claim that Windows/macOS/Linux builds are downloadable when the repository currently publishes Android APK artifacts. It presents Android as available, source as available, and the web edition as in development.

## Deployment

The structure remains compatible with a root-hosted static site/GitHub Pages-style deployment. No Node build step, npm install, bundler or server is required.

Before pushing:

```bash
git status
git diff -- index.html pocketllm-website/
```

Then commit the redesign normally.
